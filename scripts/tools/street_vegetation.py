"""Small, bent street plants authored in metres, shared by both street exports.

This is geometry, not crossed alpha cards. Emitters accept per-vertex linear
colours and receive Godot X/Y-up/Z coordinates before the sole GLB conversion.
No randomness is global, and plants never create collision volumes.
"""
import math
import random


def mix(a, b, t):
    return tuple(x * (1.0 - t) + y * t for x, y in zip(a, b))


def curved_leaf(emit, at, angle, length, width, rise, seed, dry=False,
                segments=4, material='verge_green', curl=.22):
    """A folded ribbon with a curved, drooping tip and a tapered outline.

    Width is the full width. A leaf's maximum rise is independent of its reach,
    so a 7 cm wall-joint leaf cannot turn into a 40 cm upright dagger.
    """
    rng = random.Random(seed)
    dx, dz = math.cos(angle), math.sin(angle)
    sx, sz = -dz, dx
    x, y, z = at
    lean = rng.uniform(-.18, .18)
    verts, colours, faces = [], [], []
    base = ((.105, .083, .039, 1.) if dry else (.040, .064, .024, 1.))
    body = ((.22, .161, .069, 1.) if dry else (.080, .120, .040, 1.))
    tip = ((.27, .202, .098, 1.) if dry else (.125, .143, .052, 1.))
    value = rng.uniform(.81, 1.15)
    body = tuple(c * value if i < 3 else c for i, c in enumerate(body))
    # Use open V folds rather than triangular prism leaves. The narrow edges,
    # dark base, sun-worn tip and bent midrib remain visible at player distance.
    for j in range(segments):
        t = j / segments
        reach = length * (t * .58 + t * t * .42)
        sideways = lean * length * math.sin(math.pi * t)
        height = rise * (math.sin(t * math.pi * .69) + .15 * t)
        height -= length * curl * (t ** 3)
        cx, cz = x + dx * reach + sx * sideways, z + dz * reach + sz * sideways
        cy = y + max(.001 * t, height)
        flare = math.sin(math.pi * (.06 + .90 * t)) ** .83
        half = width * .5 * flare
        colour = mix(base, body, min(1., t * 3.5))
        colour = mix(colour, tip, max(0., t - .65) * 1.4)
        for side in [-1, 0, 1]:
            fold = width * .115 * flare if side == 0 else 0.
            verts.append((cx + sx * half * side, cy + fold, cz + sz * half * side))
            colours.append(tuple(c * (1.06 if side == 0 and i < 3 else 1.)
                                 for i, c in enumerate(colour)))
    tip_y = y + max(.002, rise * (math.sin(math.pi * .69) + .15) - length * curl)
    verts.append((x + dx * length, tip_y, z + dz * length))
    colours.append(tip)
    for j in range(segments - 1):
        a = j * 3
        faces.extend([(a, a + 3, a + 4, a + 1), (a + 1, a + 4, a + 5, a + 2)])
    a = (segments - 1) * 3
    faces.extend([(a, len(verts) - 1, a + 1), (a + 1, len(verts) - 1, a + 2)])
    emit(material, verts, faces, colours)
    return len(faces)


def seed_stem(emit, at, angle, height, seed, material='verge_green'):
    """One fine, dried seed head, used sparingly among living grass."""
    rng = random.Random(seed)
    x, y, z = at
    dx, dz = math.cos(angle), math.sin(angle)
    # Three segment strip, less than 1 mm wide. No cone/cylinder spikes.
    path = [(x + dx * height * .19 * t * t, y + height * t,
             z + dz * height * .19 * t * t) for t in [0., .35, .72, 1.]]
    for i in range(3):
        a, b = path[i:i + 2]
        width = .00065 * (1. - i * .15)
        vv = [(a[0] - dz * width, a[1], a[2] + dx * width),
              (a[0] + dz * width, a[1], a[2] - dx * width),
              (b[0] + dz * width * .75, b[1], b[2] - dx * width * .75),
              (b[0] - dz * width * .75, b[1], b[2] + dx * width * .75)]
        emit(material, vv, [(0, 1, 2, 3)], (.19, .151, .074, 1.))
    top = path[-1]
    for j in range(rng.randint(3, 5)):
        a = angle + j * 2.31
        offset = .004 + j * .001
        root = (top[0], top[1] - .006 - j * .006, top[2])
        curved_leaf(emit, root, a, offset * 1.8, .0025, .005,
                    seed + j + 99, True, 2, material, .08)


def ground_plant(emit, x, y, z, height, seed, species=None, near=False, wall_strip=False):
    """A sparse irregular patch, never a uniform radial bundle.

    Species are crabgrass, low plantain and small clover-like ground cover.
    Height is the budget, not an instruction for every leaf to reach it.
    """
    rng = random.Random(seed)
    species = species or rng.choices(['crabgrass', 'plantain', 'clover'], [6, 3, 2])[0]
    patches = rng.randint(2, 3) if near else rng.randint(1, 2)
    count = 0
    extent = .028 if near else .022
    for patch in range(patches):
        bx, bz = x + rng.uniform(-extent, extent), z + rng.uniform(-extent * .32, extent * .32)
        phase = rng.random() * math.tau
        leaves = rng.randint(3, 5) if near else rng.randint(3, 4)
        for leaf in range(leaves):
            angle = (rng.uniform(.15, math.pi - .15) if wall_strip
                     else phase + leaf * rng.uniform(1.8, 2.6))
            if species == 'plantain':
                length = height * rng.uniform(.33, .64)
                width = rng.uniform(.012, .021) * min(1., height / .10)
                rise = height * rng.uniform(.16, .35)
                curl = .11
            elif species == 'clover':
                length = height * rng.uniform(.23, .41)
                width = rng.uniform(.009, .017) * min(1., height / .10)
                rise = height * rng.uniform(.28, .50)
                curl = .08
            else:
                length = height * rng.uniform(.40, .87)
                width = rng.uniform(.0026, .0057)
                rise = height * rng.uniform(.50, 1.0)
                curl = rng.uniform(.21, .40)
            if wall_strip:
                # Main-street facade is local z=.055, NPC swept feet begin at
                # z=.155. Keep stems/leaves in that real, unwalked mortar strip.
                length = min(length, max(.015, .143 - bz))
                width = min(width, .010)
            dry = rng.random() < .17
            curved_leaf(emit, (bx, y, bz), angle, length, width, rise,
                        seed + patch * 71 + leaf, dry, 8 if near else 4,
                        curl=curl)
            count += 1
        if species == 'crabgrass' and near and rng.random() < .24:
            seed_stem(emit, (bx, y, bz), phase + .3, height * 1.05, seed + patch)
    return {'species': species, 'leaves': count, 'root': [x, y, z],
            'height_limit_m': round(height * 1.15, 4), 'collision': False}


def fallen_leaf(emit, at, angle, length, seed):
    """A curled, asymmetric dead leaf bedded just above the exact surface."""
    rng = random.Random(seed)
    return curved_leaf(emit, at, angle, length, length * rng.uniform(.30, .44),
                       length * .10, seed, True, 4, curl=.05)
