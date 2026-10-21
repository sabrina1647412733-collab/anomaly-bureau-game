"""按工程现有 walk.glb 的结构手写动画 GLB：
根节点 target_character → output_unwrapped(空) + 骨骼节点链，无 skin/mesh。
Godot 导入后轨道叶子名就是骨骼名，正好对上 xuyan_character.gd 的映射逻辑。
"""
import json
import struct
import math
import bpy
from mathutils import Matrix, Quaternion, Vector

# Blender(Z-up) -> glTF(Y-up)
C = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))
C_INV = C.inverted()


def _decompose(m):
    t = m.to_translation()
    q = m.to_quaternion()
    s = m.to_scale()
    return t, q, s


def collect_bones(arm):
    """按父子顺序返回 [(name, parent_name)]"""
    out = []

    def walk(b):
        out.append((b.name, b.parent.name if b.parent else None))
        for ch in b.children:
            walk(ch)

    for b in arm.data.bones:
        if b.parent is None:
            walk(b)
    return out


def write_clip_glb(arm, action, frames, name, path, loop=False, fps=30):
    arm.animation_data_create()
    arm.animation_data.action = action
    bones = collect_bones(arm)
    idx = {n: i for i, (n, _) in enumerate(bones)}

    # rest 的父相对矩阵
    rest_rel = {}
    rest_abs = {b.name: b.matrix_local.copy() for b in arm.data.bones}
    for n, p in bones:
        rest_rel[n] = (rest_abs[p].inverted() @ rest_abs[n]) if p else rest_abs[n]

    times = [f / fps for f in range(frames + 1)]
    trans = {n: [] for n, _ in bones}
    rots = {n: [] for n, _ in bones}

    prev_q = {}
    for f in range(frames + 1):
        bpy.context.scene.frame_set(f)
        bpy.context.view_layer.update()
        for n, _p in bones:
            pb = arm.pose.bones[n]
            m_bl = rest_rel[n] @ pb.matrix_basis
            m_gl = C @ m_bl @ C_INV
            t, q, _s = _decompose(m_gl)
            pq = prev_q.get(n)
            if pq is not None and q.dot(pq) < 0:
                q = Quaternion((-q.w, -q.x, -q.y, -q.z))
            prev_q[n] = q
            trans[n].append(t)
            rots[n].append(q)
    arm.animation_data.action = None

    # ---- 组装 glTF ----
    buf = bytearray()
    views = []
    accs = []

    def add_accessor(data, comp_type, type_str, count, minmax=None):
        nonlocal buf
        while len(buf) % 4:
            buf.append(0)
        offset = len(buf)
        if comp_type == 5126:
            for v in data:
                if isinstance(v, (list, tuple, Vector, Quaternion)):
                    buf.extend(struct.pack("<%df" % len(v), *v))
                else:
                    buf.extend(struct.pack("<f", v))
        views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(buf) - offset})
        a = {"bufferView": len(views) - 1, "componentType": comp_type,
             "count": count, "type": type_str}
        if minmax:
            a["min"], a["max"] = minmax
        accs.append(a)
        return len(accs) - 1

    t_min, t_max = [min(times)], [max(times)]
    time_acc = add_accessor(times, 5126, "SCALAR", len(times), (t_min, t_max))

    samplers, channels = [], []
    for n, _p in bones:
        node_i = idx[n] + 2  # 0:target_character 1:output_unwrapped
        rot_acc = add_accessor([(q.x, q.y, q.z, q.w) for q in rots[n]], 5126, "VEC4", len(times))
        samplers.append({"input": time_acc, "output": rot_acc, "interpolation": "LINEAR"})
        channels.append({"sampler": len(samplers) - 1, "target": {"node": node_i, "path": "rotation"}})
        tr_acc = add_accessor([(v.x, v.y, v.z) for v in trans[n]], 5126, "VEC3", len(times))
        samplers.append({"input": time_acc, "output": tr_acc, "interpolation": "LINEAR"})
        channels.append({"sampler": len(samplers) - 1, "target": {"node": node_i, "path": "translation"}})

    while len(buf) % 4:
        buf.append(0)

    nodes = [
        {"name": "target_character", "children": [1] + [i + 2 for i, (n, p) in enumerate(bones) if p is None]},
        {"name": "output_unwrapped", "children": []},
    ]
    children_map = {n: [] for n, _ in bones}
    for n, p in bones:
        if p:
            children_map[p].append(idx[n] + 2)
    for i, (n, p) in enumerate(bones):
        node = {"name": n}
        if children_map[n]:
            node["children"] = children_map[n]
        nodes.append(node)

    gltf = {
        "asset": {"version": "2.0", "generator": "xuyan-anim-writer"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": nodes,
        "buffers": [{"byteLength": len(buf)}],
        "bufferViews": views,
        "accessors": accs,
        "animations": [{
            "name": name,
            "channels": channels,
            "samplers": samplers,
            "extras": {"loop": bool(loop), "fps": fps, "duration": round(frames / fps, 4)},
        }],
    }

    js = json.dumps(gltf, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    while len(js) % 4:
        js += b" "
    bin_chunk = bytes(buf)
    while len(bin_chunk) % 4:
        bin_chunk += b"\x00"
    total = 12 + 8 + len(js) + 8 + len(bin_chunk)
    out = bytearray()
    out.extend(struct.pack("<III", 0x46546C67, 2, total))
    out.extend(struct.pack("<II", len(js), 0x4E4F534A))
    out.extend(js)
    out.extend(struct.pack("<II", len(bin_chunk), 0x004E4942))
    out.extend(bin_chunk)
    with open(path, "wb") as fh:
        fh.write(out)
    return len(out)
