using System;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Text;
using System.Web.Script.Serialization;
using AnomalyBureauDistribution;
class UpdaterTests {
    static int passed,failed;
    static string fixture,root;
    static void Check(bool ok,string name) { if(ok) { passed++; Console.WriteLine("PASS "+name); } else { failed++; Console.WriteLine("FAIL "+name); } }
    static void Throws(Action action,string name) { bool threw=false; try {action();} catch {threw=true;} Check(threw,name); }
    static void Reset() {
        if(Directory.Exists(root)) Directory.Delete(root,true);
        Directory.CreateDirectory(Path.Combine(root,"_更新缓存"));
        Directory.CreateDirectory(Path.Combine(root,"_玩家数据"));
        File.WriteAllText(Path.Combine(root,"_玩家数据","save_1.json"),"player-save-sentinel");
        File.WriteAllText(Path.Combine(root,"_玩家数据","settings.cfg"),"settings-sentinel");
        foreach(string name in Launcher.Allowed) File.WriteAllText(Path.Combine(root,name),"old:"+name);
    }
    static Job Package(string extra) {
        string pack=Path.Combine(root,"_更新缓存","download.zip");
        if(File.Exists(pack)) File.Delete(pack);
        string src=Path.Combine(root,"fixture"); Directory.CreateDirectory(src);
        File.Copy(fixture,Path.Combine(src,Launcher.Allowed[0]),true);
        File.WriteAllText(Path.Combine(src,Launcher.Allowed[1]),"new-resource-pack");
        var files=Launcher.Allowed.Select(name=>new PayloadFile{path=name,size=new FileInfo(Path.Combine(src,name)).Length,sha256=Launcher.Hash(Path.Combine(src,name))}).ToArray();
        var manifest=new Manifest{protocol=1,version="0.6.1",files=files};
        using(var zip=ZipFile.Open(pack,ZipArchiveMode.Create)) {
            var e=zip.CreateEntry("manifest.json");
            using(var writer=new StreamWriter(e.Open(),new UTF8Encoding(false))) writer.Write(new JavaScriptSerializer().Serialize(manifest));
            foreach(string name in Launcher.Allowed) zip.CreateEntryFromFile(Path.Combine(src,name),name);
            if(extra!=null) { var x=zip.CreateEntry(extra); using(var w=new StreamWriter(x.Open())) w.Write("untrusted"); }
        }
        return new Job{install_dir=root,archive=pack,sha256=Launcher.Hash(pack),version="0.6.1",token=Guid.NewGuid().ToString("N"),game_args=new string[0]};
    }
    static void Old(string label) {
        Check(Launcher.Allowed.All(n=>File.ReadAllText(Path.Combine(root,n))=="old:"+n),label+" runtime restored");
        Check(File.ReadAllText(Path.Combine(root,"_玩家数据","save_1.json"))=="player-save-sentinel" && File.ReadAllText(Path.Combine(root,"_玩家数据","settings.cfg"))=="settings-sentinel",label+" save/settings unchanged");
    }
    public static int Main(string[] args) {
        root=Path.GetFullPath(args[0]); fixture=Path.GetFullPath(args[1]);
        if(!Path.GetFileName(root).StartsWith("sandbox-")) throw new Exception("Tests require a sandbox-* directory");
        Reset(); var job=Package(null); Launcher.Apply(root,job);
        Check(Launcher.Hash(Path.Combine(root,Launcher.Allowed[0]))==Launcher.Hash(fixture),"valid package applied");
        Check(Launcher.Confirm(root,job),"healthy child commits transaction");
        Check(!Launcher.Recover(root),"committed update is not reverted");
        Check(File.ReadAllText(Path.Combine(root,"_玩家数据","save_1.json"))=="player-save-sentinel","successful update protects saves");
        System.Threading.Thread.Sleep(1800);
        Reset(); job=Package(null); job.sha256=new string('0',64); Throws(()=>Launcher.Apply(root,job),"bad archive checksum rejected"); Old("bad checksum");
        Reset(); job=Package("../_玩家数据/save_1.json"); Throws(()=>Launcher.Apply(root,job),"path traversal/extra entries rejected"); Old("hostile archive");
        Reset(); job=Package(null); job.version="0.7.0"; Throws(()=>Launcher.Apply(root,job),"manifest version mismatch rejected"); Old("version mismatch");
        Reset(); job=Package(null);
        Launcher.Fault=p=>{throw new IOException("injected replacement failure");};
        Throws(()=>Launcher.Apply(root,job),"injected replacement failure"); Launcher.Fault=null; Old("replacement failure");
        Reset(); job=Package(null);
        using(var locked=File.Open(Path.Combine(root,Launcher.Allowed[1]),FileMode.Open,FileAccess.Read,FileShare.None))
            Throws(()=>Launcher.Apply(root,job),"locked old file rejected before replacement");
        Old("locked old file");
        Reset(); job=Package(null); Launcher.Apply(root,job);
        Check(Launcher.Recover(root),"interrupted transaction recovered on next launcher start"); Old("interruption");
        Reset(); job=Package(null); job.game_args=new[]{"--fail"}; Launcher.Apply(root,job);
        Check(!Launcher.Confirm(root,job),"unhealthy new version triggers rollback"); Old("unhealthy child");
        Reset(); job=Package(null); Launcher.Apply(root,job);
        var journal=Launcher.Read<Journal>(Path.Combine(root,"_更新缓存","transaction.json"));
        Launcher.Rollback(root,journal,"test"); Launcher.Rollback(root,journal,"test again"); Old("idempotent rollback");
        Check(Launcher.Quote("a b\\")=="\"a b\\\\\"","trailing slash argument quoting");
        Console.WriteLine("RESULT "+passed+" passed, "+failed+" failed"); return failed==0?0:1;
    }
}
