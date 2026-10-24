// One-time v0.6.x migration. Old protocol still receives exactly its two allowed
// files; the bridge PCK hands off to this independently staged, verified helper.
using System;
using System.IO;
using System.Linq;
using System.Diagnostics;
using System.Threading;
using System.Collections.Generic;

namespace AnomalyBureauDistribution {
public sealed class Layout { public int protocol; public PayloadFile[] files; }
public sealed class MigrationJournal {
    public string state,token;
    public int child_pid;
    public List<string> existed=new List<string>();
    public List<string> touched=new List<string>();
}
public static class Migration {
    internal static Action<string> Fault;
    static readonly string[] Mutable={"AnomalyBureau.exe","AnomalyBureau.Game.exe","AnomalyBureau.Game.pck","_运行文件/active.json"};
    static string Dir(string root) {return Path.Combine(root,"_更新缓存","migration");}
    static string Journal(string root) {return Path.Combine(Dir(root),"transaction.json");}
    static string Backup(string root,string path) {return Path.Combine(Dir(root),"backup",path.Replace('/','_'));}
    static bool Allowed(string path) {
        return Mutable.Contains(path)||new[]{"AnomalyBureau.ico","开始游玩说明.txt","兼容模式启动.bat","自动更新说明.txt","Godot-LICENSE.txt","Godot-COPYRIGHT.txt","NotoSansSC-LICENSE.txt","credits.txt","CC-BY-4.0.txt","CC0-1.0.txt"}.Contains(path)
            ||System.Text.RegularExpressions.Regex.IsMatch(path??"",@"^_运行文件/packs/(base|code_ui|maps|case1|case2|characters_audio)-[a-f0-9]{64}\.zip$");
    }
    internal static Layout Validate(string stage) {
        Grouped.Plain(stage); var layout=Grouped.Read<Layout>(Path.Combine(stage,"layout.json"));
        if(layout.protocol!=1||layout.files==null||layout.files.Length<5||layout.files.Select(f=>f.path).Distinct(StringComparer.OrdinalIgnoreCase).Count()!=layout.files.Length||Mutable.Any(p=>!layout.files.Any(f=>f.path==p))) throw new InvalidDataException("迁移清单结构无效");
        foreach(var f in layout.files) {
            if(!Allowed(f.path)) throw new InvalidDataException("迁移清单含非法路径");
            string p=Path.Combine(stage,f.path); Grouped.Plain(p);
            if(!File.Exists(p)||new FileInfo(p).Length!=f.size||Launcher.Hash(p)!=f.sha256) throw new InvalidDataException("迁移文件校验失败："+f.path);
        }
        Grouped.Validate(Path.Combine(stage,"_运行文件","active.json")); return layout;
    }
    static void Copy(string source,string dest) {
        Grouped.Plain(source); Grouped.Plain(dest); Directory.CreateDirectory(Path.GetDirectoryName(dest));
        string tmp=dest+".migration"; Grouped.Plain(tmp);
        using(var input=File.OpenRead(source)) using(var output=new FileStream(tmp,FileMode.Create,FileAccess.Write,FileShare.None)) {input.CopyTo(output); output.Flush(true);}
        if(File.Exists(dest)) File.Replace(tmp,dest,null); else File.Move(tmp,dest);
    }
    static void Rollback(string root,MigrationJournal j) {
        j.state="rolling_back"; Grouped.Write(Journal(root),j);
        foreach(string p in j.touched.AsEnumerable().Reverse()) {
            if(!Mutable.Contains(p)) throw new InvalidDataException("迁移回滚路径无效");
            string dest=Path.Combine(root,p); Grouped.Plain(dest);
            if(j.existed.Contains(p)) Copy(Backup(root,p),dest); else if(File.Exists(dest)) File.Delete(dest);
        }
        j.state="rolled_back"; Grouped.Write(Journal(root),j);
        Grouped.Write(Path.Combine(root,"_更新缓存","result.json"),new {status="rolled_back",message="基础包迁移失败，已恢复迁移前的运行文件。存档设置保留。"});
    }
    internal static bool Recover(string root) {
        if(!File.Exists(Journal(root))) return false;
        var j=Grouped.Read<MigrationJournal>(Journal(root)); if(j.state=="committed"||j.state=="rolled_back") return false;
        if(j.child_pid>0) {
            try {var p=Process.GetProcessById(j.child_pid); if(!p.HasExited&&String.Equals(p.MainModule.FileName,Path.Combine(root,"AnomalyBureau.Game.exe"),StringComparison.OrdinalIgnoreCase)) throw new IOException("请先正常退出迁移后的游戏，再启动恢复。");} catch(ArgumentException){}
        }
        Rollback(root,j); return true;
    }
    internal static int Install(string[] args) {
        string root=Path.GetFullPath(args[1]),stage=Path.GetFullPath(args[2]),status=args[3];
        bool legacy=args.Length>5&&args[5]=="--from-legacy";
        string[] gameArgs=args.Skip(legacy?6:5).ToArray();
        try {
            var layout=Validate(stage); Grouped.Plain(root); Directory.CreateDirectory(Dir(root));
            try {var p=Process.GetProcessById(Int32.Parse(args[4])); if(String.Equals(p.MainModule.FileName,Path.Combine(root,"AnomalyBureau.Game.exe"),StringComparison.OrdinalIgnoreCase)) p.WaitForExit(60000);} catch(ArgumentException){}
            FileStream gate=null; var wait=Stopwatch.StartNew();
            while(gate==null&&wait.Elapsed.TotalSeconds<150) {
                try {gate=new FileStream(Path.Combine(root,"_更新缓存","update.lock"),FileMode.OpenOrCreate,FileAccess.ReadWrite,FileShare.None);} catch(IOException) {Thread.Sleep(250);}
            }
            if(gate==null) throw new IOException("旧更新器尚未完成，请稍后重新启动迁移。");
            using(gate) {
                Recover(root); var j=new MigrationJournal {state="preparing",token=Guid.NewGuid().ToString("N")};
                Directory.CreateDirectory(Path.Combine(Dir(root),"backup"));
                foreach(string p in Mutable) if(File.Exists(Path.Combine(root,p))) {
                    string source=Path.Combine(root,p);
                    string legacyBackup=Path.Combine(root,"_更新缓存","backup",p);
                    // The root currently holds the bridge, not the old playable PCK.
                    if(legacy&&p.StartsWith("AnomalyBureau.Game.")&&File.Exists(legacyBackup)) {
                        var old=Grouped.Read<Journal>(Path.Combine(root,"_更新缓存","transaction.json"));
                        if(old.state=="committed"&&old.version==Grouped.Validate(Path.Combine(stage,"_运行文件","active.json")).version) source=legacyBackup;
                    }
                    Copy(source,Backup(root,p)); j.existed.Add(p);
                }
                // Immutable packs are complete before the activation pointer changes.
                foreach(var f in layout.files.Where(f=>!Mutable.Contains(f.path))) Copy(Path.Combine(stage,f.path),Path.Combine(root,f.path));
                Grouped.Write(Journal(root),j);
                foreach(string p in Mutable) {
                    j.touched.Add(p); Grouped.Write(Journal(root),j); Copy(Path.Combine(stage,p),Path.Combine(root,p));
                    if(Fault!=null) Fault("replaced:"+p);
                }
                string receipt=Path.Combine(Dir(root),"health-"+j.token+".txt");
                var a=new List<string>(gameArgs); if(!a.Contains("--")) a.Add("--"); a.Add("--migration-health="+receipt); a.Add("--migration-token="+j.token);
                Process child=null;
                try {
                    child=Grouped.Start(root,a.ToArray()); j.child_pid=child.Id; j.state="launching"; Grouped.Write(Journal(root),j);
                    var timer=Stopwatch.StartNew(); bool healthy=false;
                    while(timer.Elapsed.TotalSeconds<120&&!child.HasExited) {
                        if(File.Exists(receipt)&&File.ReadAllText(receipt).Trim()==j.token) {Thread.Sleep(2000); healthy=!child.HasExited; break;}
                        Thread.Sleep(100);
                    }
                    if(!healthy) throw new IOException("迁移后的游戏未进入主菜单");
                    j.state="committed"; Grouped.Write(Journal(root),j); Grouped.Write(status,new {state="committed",message="分组基础包迁移完成"});
                } catch {
                    if(child!=null&&!child.HasExited) {child.Kill(); child.WaitForExit(10000);}
                    Rollback(root,j); throw;
                }
            }
            return 0;
        } catch(Exception e) {
            try {
                // Reacquire the stable launcher's gate after an exception unwinds
                // the install scope. Never race its next-start recovery.
                Directory.CreateDirectory(Dir(root));
                using(var recoveryGate=new FileStream(Path.Combine(root,"_更新缓存","update.lock"),FileMode.OpenOrCreate,FileAccess.ReadWrite,FileShare.None)) {
                Recover(root);
                if(legacy&&!File.Exists(Path.Combine(root,"_运行文件","active.json"))) {
                    foreach(string p in new[]{"AnomalyBureau.Game.exe","AnomalyBureau.Game.pck"}) {
                        string old=Path.Combine(root,"_更新缓存","backup",p);
                        if(File.Exists(old)) Copy(old,Path.Combine(root,p));
                    }
                }
                Grouped.Write(Path.Combine(root,"_更新缓存","result.json"),new {status="failed",message="基础包迁移失败，原版本已保留："+e.Message});
                Grouped.Start(root,gameArgs);
                }
            } catch(Exception recovery) {Grouped.Write(status,new {state="error",message=e.Message+"；恢复："+recovery.Message}); return 1;}
            Grouped.Write(status,new {state="error",message=e.Message}); return 1;
        }
    }
}
}
