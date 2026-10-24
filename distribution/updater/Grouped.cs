// Protocol 2: content addressed transport, locally merged groups, atomic activation.
using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Net;
using System.Threading;
using System.Diagnostics;
using System.Collections.Generic;
using System.IO.Compression;
using System.Web.Script.Serialization;
using System.Security.Cryptography;

namespace AnomalyBureauDistribution {
public sealed class ResourceFile {
    public string path, group, sha256, asset, download_sha256, bundle;
    public long size, download_size, offset;
}
public sealed class GroupManifest {
    public int protocol;
    public string version, baseline;
    public ResourceFile[] files;
}
public sealed class GroupPlan {
    public long bytes;
    public string state, message;
    public string[] assets;
}
public sealed class GroupJournal {
    public string state, old_manifest, new_manifest, token;
    public int child_pid;
}
public static class Grouped {
    static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = 32*1024*1024 };
    internal static readonly string[] Groups = { "base", "code_ui", "maps", "case1", "case2", "characters_audio" };
    internal static Action<string> Fault;
    internal static int HealthSeconds = 120;
    static void Hit(string p) { if (Fault!=null) Fault(p); }
    internal static string Runtime(string root) { return Path.Combine(root,"_运行文件"); }
    internal static string Cache(string root) { return Path.Combine(root,"_更新缓存","v2"); }
    static string Active(string root) { return Path.Combine(Runtime(root),"active.json"); }
    static string Journal(string root) { return Path.Combine(Cache(root),"transaction.json"); }
    static bool Digest(string v) { return System.Text.RegularExpressions.Regex.IsMatch(v??"", "^[a-f0-9]{64}$"); }
    internal static void Plain(string path) {
        for (string p=Path.GetFullPath(path); !String.IsNullOrEmpty(p); p=Path.GetDirectoryName(p))
            if ((Directory.Exists(p)||File.Exists(p)) && (File.GetAttributes(p)&FileAttributes.ReparsePoint)!=0)
                throw new IOException("不允许通过目录联接或符号链接更新："+p);
    }
    internal static T Read<T>(string path) { return Json.Deserialize<T>(File.ReadAllText(path,Encoding.UTF8)); }
    internal static void Write(string path, object value) { Launcher.WriteJson(path,value); }
    internal static GroupManifest Validate(string path) {
        if (new FileInfo(path).Length>16*1024*1024) throw new InvalidDataException("资源清单过大");
        var m=Read<GroupManifest>(path);
        if (m==null || m.protocol!=2 || !System.Text.RegularExpressions.Regex.IsMatch(m.version??"",@"^\d+\.\d+\.\d+$") || !Digest(m.baseline) || m.files==null || m.files.Length==0 || m.files.Length>20000)
            throw new InvalidDataException("不支持的分组更新清单");
        var paths=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var f in m.files) {
            if (String.IsNullOrEmpty(f.path)||f.path.StartsWith("/")||f.path.Contains("\\")||f.path.Contains(":")||f.path.Split('/').Any(s=>s==".."||s=="."||s.Length==0)||!paths.Add(f.path)||!Groups.Contains(f.group)||!Digest(f.sha256)||!Digest(f.download_sha256)||f.size<0||f.size>2000000000L||f.download_size<=0||f.download_size>2000000000L||f.asset!="r-"+f.sha256+".zip")
                throw new InvalidDataException("资源清单包含非法路径、分组或校验值");
            if(!String.IsNullOrEmpty(f.bundle) && (!Groups.Any(g=>f.bundle=="AnomalyBureau-resources-"+g+".bin")||f.offset<0||f.offset>20000000000L))
                throw new InvalidDataException("资源分组容器或偏移无效");
        }
        return m;
    }
    internal static string GroupId(IEnumerable<ResourceFile> files) {
        string joined=String.Join("\n",files.OrderBy(f=>f.path,StringComparer.Ordinal).Select(f=>f.path+"\t"+f.sha256+"\t"+f.size.ToString(System.Globalization.CultureInfo.InvariantCulture)));
        using(var sha=SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(Encoding.UTF8.GetBytes(joined))).Replace("-","").ToLowerInvariant();
    }
    internal static string Pack(string root, string group, IEnumerable<ResourceFile> files) {
        return Path.Combine(Runtime(root),"packs",group+"-"+GroupId(files)+".zip");
    }
    static string Blob(string root, ResourceFile f) { return Path.Combine(Cache(root),"downloads",f.asset); }
    static bool GoodBlob(string root, ResourceFile f) {
        string p=Blob(root,f); Plain(p);
        return File.Exists(p)&&new FileInfo(p).Length==f.download_size&&Launcher.Hash(p)==f.download_sha256;
    }
    static string StreamHash(Stream stream) {
        using (var sha=SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-","").ToLowerInvariant();
    }
    // Only return verified sources. Corrupt/missing local entries become repair downloads.
    internal static Dictionary<string,string> LocalSources(string root, HashSet<string> verifiedEntries=null) {
        var result=new Dictionary<string,string>();
        if (!File.Exists(Active(root))) return result;
        var m=Validate(Active(root));
        foreach(string g in Groups) {
            var files=m.files.Where(f=>f.group==g).ToArray(); if(files.Length==0) continue;
            string p=Pack(root,g,files); Plain(p); if(!File.Exists(p)) continue;
            try {
                using(var zip=ZipFile.OpenRead(p)) foreach(var f in files) {
                    var e=zip.GetEntry(f.path); if(e==null||e.Length!=f.size) continue;
                    try { using(var s=e.Open()) if(StreamHash(s)==f.sha256) {
                        result[f.sha256]=p+"|"+f.path;
                        if(verifiedEntries!=null) verifiedEntries.Add(p+"|"+f.path);
                    } }
                    catch(InvalidDataException) { /* only the damaged resource needs repair */ }
                }
            } catch(InvalidDataException) { /* repair an unreadable group */ }
        }
        return result;
    }
    internal static void CheckBaseline(string root, GroupManifest m) {
        string actual=Launcher.Hash(Path.Combine(root,"AnomalyBureau.Game.exe"))+Launcher.Hash(Path.Combine(root,"AnomalyBureau.Game.pck"));
        using(var sha=SHA256.Create()) actual=BitConverter.ToString(sha.ComputeHash(Encoding.ASCII.GetBytes(actual))).Replace("-","").ToLowerInvariant();
        if(actual!=m.baseline) throw new InvalidDataException("基础运行文件不匹配，请安装同版本完整包修复后重试。");
    }
    internal static GroupPlan Plan(string root,string manifest) {
        Plain(root); Plain(Cache(root)); var m=Validate(manifest); CheckBaseline(root,m);
        var local=LocalSources(root);
        var missing=m.files.GroupBy(f=>f.sha256).Select(g=>g.First()).Where(f=>!local.ContainsKey(f.sha256)&&!GoodBlob(root,f)).ToArray();
        return new GroupPlan { bytes=missing.Sum(f=>f.download_size), assets=missing.Select(f=>f.asset).ToArray(),state="available",message="已校验本地资源，可开始更新或修复。" };
    }
    static Uri AssetUri(string baseUrl,string asset) {
        var b=new Uri(baseUrl.TrimEnd('/')+"/");
        // Loopback is permitted for isolated acceptance only; production manifest URLs
        // are additionally constrained by update_service to the fixed public repository.
        if (!(b.IsLoopback&&b.Scheme=="http") && !(b.Scheme=="https"&&b.Host=="github.com"&&b.AbsolutePath.StartsWith("/sabrina1647412733-collab/anomaly-bureau-game/releases/download/v")))
            throw new InvalidDataException("资源下载地址无效");
        return new Uri(b,asset);
    }
    internal static void Download(string root,string manifest,string baseUrl,string status) {
        var m=Validate(manifest); CheckBaseline(root,m);
        var local=LocalSources(root);
        var missing=m.files.GroupBy(f=>f.sha256).Select(g=>g.First()).Where(f=>!local.ContainsKey(f.sha256)&&!GoodBlob(root,f)).ToArray();
        long total=missing.Sum(f=>f.download_size),done=0;
        Directory.CreateDirectory(Path.Combine(Cache(root),"downloads"));
        foreach(var f in missing) {
            string dest=Blob(root,f),part=dest+".part"; Plain(dest); Plain(part);
            Exception last=null;
            for(int attempt=1;attempt<=3;attempt++) {
                try {
                    if(File.Exists(status+".cancel")) throw new OperationCanceledException("已取消下载，完整校验的文件已保留。");
                    bool ranged=!String.IsNullOrEmpty(f.bundle);
                    var request=(HttpWebRequest)WebRequest.Create(AssetUri(baseUrl,ranged?f.bundle:f.asset));
                    if(ranged) request.AddRange(f.offset,f.offset+f.download_size-1);
                    request.UserAgent="AnomalyBureau"; request.Timeout=20000; request.ReadWriteTimeout=20000;
                    using(var response=(HttpWebResponse)request.GetResponse())
                    using(var input=response.GetResponseStream())
                    using(var output=new FileStream(part,FileMode.Create,FileAccess.Write,FileShare.Read)) {
                        if(ranged && (response.StatusCode!=HttpStatusCode.PartialContent || response.Headers["Content-Range"]==null || !response.Headers["Content-Range"].StartsWith("bytes "+f.offset+"-"+(f.offset+f.download_size-1)+"/")))
                            throw new InvalidDataException("下载服务不支持所需分段读取，请重试或使用完整安装包。");
                        var buffer=new byte[65536]; long length=0; int count; var timer=Stopwatch.StartNew();
                        while((count=input.Read(buffer,0,buffer.Length))>0) {
                            if(File.Exists(status+".cancel")) throw new OperationCanceledException("已取消下载，完整校验的文件已保留。");
                            length+=count; if(length>f.download_size) throw new InvalidDataException("下载文件超出清单长度");
                            output.Write(buffer,0,count);
                            if(timer.ElapsedMilliseconds>=100 || length==f.download_size) {
                                Write(status,new {state="downloading",bytes=done+length,total=total,asset=f.asset,attempt=attempt,message="正在下载所需资源…"}); timer.Restart();
                            }
                        }
                        output.Flush(true);
                    }
                    if(new FileInfo(part).Length!=f.download_size||Launcher.Hash(part)!=f.download_sha256) throw new InvalidDataException("下载不完整或 SHA256 校验失败："+f.asset);
                    if(File.Exists(dest)) File.Delete(dest); File.Move(part,dest); done+=f.download_size; last=null; Hit("downloaded:"+f.asset); break;
                } catch(OperationCanceledException) { throw; }
                  catch(Exception e) { last=e; if(attempt<3) Thread.Sleep(300); }
            }
            if(last!=null) throw new IOException("下载重试三次仍失败："+f.asset+"；"+last.Message,last);
        }
        Write(status,new {state="downloaded",bytes=done,total=total,message="所需资源已全部校验，等待重新启动。"});
    }
    internal static void Assemble(string root,string manifest) {
        var m=Validate(manifest); CheckBaseline(root,m);
        var verified=new HashSet<string>(StringComparer.Ordinal); var local=LocalSources(root,verified);
        Directory.CreateDirectory(Path.Combine(Runtime(root),"packs"));
        foreach(string g in Groups) {
            var files=m.files.Where(f=>f.group==g).OrderBy(f=>f.path,StringComparer.Ordinal).ToArray(); if(files.Length==0) continue;
            string dest=Pack(root,g,files),tmp=dest+".tmp"; Plain(dest); Plain(tmp);
            // The expected pack may be corrupt; always rebuild changed or unverified packs.
            if(File.Exists(dest)&&files.All(f=>verified.Contains(dest+"|"+f.path))) continue;
            if(File.Exists(tmp)) File.Delete(tmp);
            using(var zip=ZipFile.Open(tmp,ZipArchiveMode.Create)) foreach(var f in files) {
                var e=zip.CreateEntry(f.path,CompressionLevel.Optimal); e.LastWriteTime=new DateTimeOffset(2000,1,1,0,0,0,TimeSpan.Zero);
                using(var output=e.Open()) {
                    string source;
                    if(local.TryGetValue(f.sha256,out source)) {
                        int sep=source.IndexOf('|');
                        using(var old=ZipFile.OpenRead(source.Substring(0,sep))) using(var input=old.GetEntry(source.Substring(sep+1)).Open()) input.CopyTo(output);
                    } else {
                        if(!GoodBlob(root,f)) throw new IOException("资源缺失或损坏，请重新下载："+f.path);
                        using(var blob=ZipFile.OpenRead(Blob(root,f))) {
                            if(blob.Entries.Count!=1||blob.Entries[0].FullName!="data"||blob.Entries[0].Length!=f.size) throw new InvalidDataException("资源传输包结构错误");
                            using(var input=blob.Entries[0].Open()) input.CopyTo(output);
                        }
                    }
                }
            }
            // Verify the reconstructed output, including resource content, before activation.
            using(var zip=ZipFile.OpenRead(tmp)) foreach(var f in files) {
                var e=zip.GetEntry(f.path); if(e==null||e.Length!=f.size) throw new InvalidDataException("合并长度错误");
                using(var s=e.Open()) if(StreamHash(s)!=f.sha256) throw new InvalidDataException("合并校验失败："+f.path);
            }
            if(File.Exists(dest)) File.Delete(dest); File.Move(tmp,dest); Hit("assembled:"+g);
        }
    }
    static string SavedManifest(string root,string hash) {
        if(!Digest(hash)) throw new InvalidDataException("事务清单校验值无效");
        return Path.Combine(Runtime(root),"manifests",hash+".json");
    }
    internal static void Activate(string root,string manifest,string token) {
        Assemble(root,manifest);
        string old=Launcher.Hash(Active(root)),next=Launcher.Hash(manifest);
        Directory.CreateDirectory(Path.Combine(Runtime(root),"manifests"));
        File.Copy(Active(root),SavedManifest(root,old),true); File.Copy(manifest,SavedManifest(root,next),true);
        var j=new GroupJournal {state="activating",old_manifest=old,new_manifest=next,token=token};
        Write(Journal(root),j); Hit("before-activate");
        AtomicCopy(manifest,Active(root)); Hit("after-activate");
        j.state="launching"; Write(Journal(root),j);
    }
    static void AtomicCopy(string source,string dest) {
        Plain(dest); string tmp=dest+".new"; Plain(tmp);
        using(var input=File.OpenRead(source)) using(var output=new FileStream(tmp,FileMode.Create,FileAccess.Write,FileShare.None)) {input.CopyTo(output); output.Flush(true);}
        if(File.Exists(dest)) File.Replace(tmp,dest,null); else File.Move(tmp,dest);
    }
    internal static bool Recover(string root) {
        if(!File.Exists(Journal(root))) return false;
        var j=Read<GroupJournal>(Journal(root)); if(j.state=="committed"||j.state=="rolled_back") return false;
        if(j.child_pid>0) {
            try {var p=Process.GetProcessById(j.child_pid); if(!p.HasExited&&String.Equals(p.MainModule.FileName,Path.Combine(root,"AnomalyBureau.Game.exe"),StringComparison.OrdinalIgnoreCase)) throw new IOException("请先正常退出游戏，再启动以恢复更新。");} catch(ArgumentException) {}
        }
        Rollback(root,j,"上次更新中断，已恢复原版本。"); return true;
    }
    internal static void Rollback(string root,GroupJournal j,string reason) {
        string old=SavedManifest(root,j.old_manifest); Plain(old);
        if(Launcher.Hash(old)!=j.old_manifest) throw new InvalidDataException("旧清单损坏，保留现场等待完整安装修复。");
        AtomicCopy(old,Active(root)); j.state="rolled_back"; Write(Journal(root),j);
        Write(Path.Combine(root,"_更新缓存","result.json"),new {status="rolled_back",version=Validate(old).version,message=reason});
    }
    internal static Process Start(string root,string[] args) {
        return Process.Start(new ProcessStartInfo(Path.Combine(root,"AnomalyBureau.Game.exe"),String.Join(" ",args.Select(Launcher.Quote))) {WorkingDirectory=root,UseShellExecute=false,CreateNoWindow=args.Contains("--headless")});
    }
    internal static bool Confirm(string root,string[] args) {
        var j=Read<GroupJournal>(Journal(root));
        if(Launcher.Hash(Active(root))!=j.new_manifest) throw new InvalidDataException("当前资源指针与目标事务不一致");
        string receipt=Path.Combine(Cache(root),"health-"+j.token+".txt"); if(File.Exists(receipt)) File.Delete(receipt);
        var a=new List<string>(args); if(!a.Contains("--")) a.Add("--");
        a.Add("--group-health="+receipt); a.Add("--group-token="+j.token);
        Process child=null;
        try {
            child=Start(root,a.ToArray()); j.child_pid=child.Id; Write(Journal(root),j);
            var timer=Stopwatch.StartNew();
            while(timer.Elapsed.TotalSeconds<HealthSeconds&&!child.HasExited) {
                if(File.Exists(receipt)&&File.ReadAllText(receipt).Trim()==j.token) {
                    Thread.Sleep(2000); if(child.HasExited) break;
                    if(Launcher.Hash(Active(root))!=j.new_manifest) throw new InvalidDataException("健康确认前资源指针被更改");
                    j.state="committed"; Write(Journal(root),j);
                    Write(Path.Combine(root,"_更新缓存","result.json"),new {status="committed",version=Validate(Active(root)).version,message="更新完成"});
                    try {Collect(root,j);} catch(IOException) { /* cleanup can retry after a file lock is released */ }
                    return true;
                }
                Thread.Sleep(100);
            }
            if(!child.HasExited) {child.Kill(); child.WaitForExit(10000);}
            Rollback(root,j,"新版本未能进入主菜单，已恢复旧版本。"); return false;
        } catch {
            if(child!=null&&!child.HasExited) {child.Kill(); child.WaitForExit(10000);}
            Rollback(root,j,"新版本启动失败，已恢复旧版本。"); throw;
        }
    }
    // At most active + previous sets of merged packs; no overlay chains.
    static void Collect(string root,GroupJournal j) {
        var keep=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach(string hash in new[]{j.old_manifest,j.new_manifest}) {
            var m=Validate(SavedManifest(root,hash));
            foreach(string g in Groups) {var f=m.files.Where(x=>x.group==g).ToArray(); if(f.Length>0) keep.Add(Pack(root,g,f));}
        }
        string dir=Path.Combine(Runtime(root),"packs"); Plain(dir);
        foreach(string p in Directory.GetFiles(dir,"*.zip")) if(!keep.Contains(p)) {Plain(p); File.Delete(p);}
        foreach(string p in Directory.GetFiles(Path.Combine(Runtime(root),"manifests"),"*.json"))
            if(!new[]{j.old_manifest,j.new_manifest}.Contains(Path.GetFileNameWithoutExtension(p))) {Plain(p); File.Delete(p);}
        // Verified downloads survive failure/cancel; after commit all exist in merged packs.
        string downloads=Path.Combine(Cache(root),"downloads"); Plain(downloads);
        if(Directory.Exists(downloads)) foreach(string p in Directory.GetFiles(downloads)) {Plain(p); File.Delete(p);}
    }
    internal static int Command(string[] args) {
        // Helpers never show UI, and report errors to an F-drive status file.
        string root=Path.GetFullPath(args[1]),manifest=args[2],status=args[3];
        try {
            Plain(root); Plain(Cache(root)); Directory.CreateDirectory(Cache(root));
            using(var gate=new FileStream(Path.Combine(Cache(root),"worker.lock"),FileMode.OpenOrCreate,FileAccess.ReadWrite,FileShare.None)) {
                if(args[0]=="--group-plan") Write(status,Plan(root,manifest));
                else if(args[0]=="--group-download") Download(root,manifest,args[4],status);
                else if(args[0]=="--group-apply") {
                    // Share the stable launcher's gate for the complete activation,
                    // confirmation and recovery phase. A second launch cannot roll
                    // back an update while its worker is still confirming it.
                    using(var launchGate=new FileStream(Path.Combine(root,"_更新缓存","update.lock"),FileMode.OpenOrCreate,FileAccess.ReadWrite,FileShare.None)) {
                        bool parentStillRunning=false;
                        string[] gameArgs=args.Skip(6).ToArray();
                        try {
                            int pid=Int32.Parse(args[4]); string token=args[5];
                            if(!System.Text.RegularExpressions.Regex.IsMatch(token,"^[a-f0-9]{32}$")) throw new InvalidDataException("令牌无效");
                            Write(status,new {state="ready",message="更新器已就绪"});
                            try {
                                var parent=Process.GetProcessById(pid);
                                if(String.Equals(parent.MainModule.FileName,Path.Combine(root,"AnomalyBureau.Game.exe"),StringComparison.OrdinalIgnoreCase)) {
                                    parentStillRunning=!parent.WaitForExit(60000);
                                    if(parentStillRunning) throw new IOException("游戏尚未退出，更新已取消。");
                                }
                            } catch(ArgumentException){}
                            Recover(root); Activate(root,manifest,token);
                            if(!Confirm(root,gameArgs)) Start(root,gameArgs);
                        } catch(Exception e) {
                            Write(status,new {state="error",message=e.Message});
                            try {Recover(root); if(!parentStillRunning) Start(root,gameArgs);}
                            catch(Exception recovery) {Write(status,new {state="error",message=e.Message+"；恢复："+recovery.Message});}
                            return 1;
                        }
                    }
                } else throw new InvalidDataException("未知更新命令");
            }
            return 0;
        } catch(Exception e) {
            Write(status,new {state="error",message=e.Message});
            return 1;
        }
    }
}
}
