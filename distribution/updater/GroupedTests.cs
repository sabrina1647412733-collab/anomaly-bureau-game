using System;
using System.IO;
using System.Linq;
using System.Text;
using System.IO.Compression;
using System.Security.Cryptography;
using AnomalyBureauDistribution;

class GroupedTests {
    static string root,fixture; static int passed,failed;
    static void Check(bool ok,string label) {Console.WriteLine((ok?"PASS ":"FAIL ")+label); if(ok)passed++;else failed++;}
    static void Throws(Action a,string label) {bool threw=false;try{a();}catch{threw=true;}Check(threw,label);}
    static string SHA(byte[] b) {using(var h=SHA256.Create())return BitConverter.ToString(h.ComputeHash(b)).Replace("-","").ToLowerInvariant();}
    static ResourceFile Resource(string path,string group,string content) {
        var bytes=Encoding.UTF8.GetBytes(content); string sha=SHA(bytes),asset="r-"+sha+".zip";
        string blob=Path.Combine(root,"server",asset); Directory.CreateDirectory(Path.GetDirectoryName(blob));
        if(!File.Exists(blob)) using(var z=ZipFile.Open(blob,ZipArchiveMode.Create)) {var e=z.CreateEntry("data");using(var s=e.Open())s.Write(bytes,0,bytes.Length);}
        return new ResourceFile{path=path,group=group,sha256=sha,size=bytes.Length,asset=asset,download_size=new FileInfo(blob).Length,download_sha256=Launcher.Hash(blob)};
    }
    static string Manifest(string version,ResourceFile[] files) {
        string baseline=SHA(Encoding.ASCII.GetBytes(Launcher.Hash(Path.Combine(root,"AnomalyBureau.Game.exe"))+Launcher.Hash(Path.Combine(root,"AnomalyBureau.Game.pck"))));
        string p=Path.Combine(root,version+".json"); Grouped.Write(p,new GroupManifest{protocol=2,version=version,baseline=baseline,files=files}); return p;
    }
    static void Cache(ResourceFile f) {
        string dir=Path.Combine(Grouped.Cache(root),"downloads");Directory.CreateDirectory(dir);
        File.Copy(Path.Combine(root,"server",f.asset),Path.Combine(dir,f.asset),true);
    }
    static void Reset() {
        if(Directory.Exists(root)) Directory.Delete(root,true);
        Directory.CreateDirectory(root);File.Copy(fixture,Path.Combine(root,"AnomalyBureau.Game.exe"));File.WriteAllText(Path.Combine(root,"AnomalyBureau.Game.pck"),"fixed-bootstrap");
        Directory.CreateDirectory(Path.Combine(root,"_玩家数据"));File.WriteAllText(Path.Combine(root,"_玩家数据","save_1.json"),"save-sentinel");File.WriteAllText(Path.Combine(root,"_玩家数据","settings.cfg"),"settings-sentinel");
    }
    static void Saves() {Check(File.ReadAllText(Path.Combine(root,"_玩家数据","save_1.json"))=="save-sentinel"&&File.ReadAllText(Path.Combine(root,"_玩家数据","settings.cfg"))=="settings-sentinel","save/settings bytes preserved");}
    static void Seed(string manifest, ResourceFile[] files) {
        Directory.CreateDirectory(Grouped.Runtime(root));
        // Assemble can start with no active pointer for a full install.
        foreach(var f in files)Cache(f);Grouped.Assemble(root,manifest);
        File.Copy(manifest,Path.Combine(Grouped.Runtime(root),"active.json"),true);
    }
    static string Active() {return Path.Combine(Grouped.Runtime(root),"active.json");}
    static void ClearDownloads(){foreach(var p in Directory.GetFiles(Path.Combine(Grouped.Cache(root),"downloads")))File.Delete(p);}
    public static int Main(string[] args) {
        root=Path.GetFullPath(args[0]);fixture=args[1];if(!Path.GetFileName(root).StartsWith("sandbox-"))return 9;
        Reset();var a=Resource("scripts/ui.gdc","code_ui","UI one");var b=Resource("assets/shared.texture","base","texture fixed");var c=Resource("assets/model.scn","maps","model one");
        var alias=Resource("assets/shared_alias.texture","base","texture fixed");
        var initial=new[]{a,b,c,alias};string m1=Manifest("0.7.0",initial);Seed(m1,initial);ClearDownloads();
        Check(Grouped.Plan(root,m1).bytes==0,"unchanged installation needs zero bytes");
        string activeBefore=Launcher.Hash(Active());
        using(var gate=new FileStream(Path.Combine(root,"_更新缓存","update.lock"),FileMode.OpenOrCreate,FileAccess.ReadWrite,FileShare.None)) {
            int blocked=Grouped.Command(new[]{"--group-apply",root,m1,Path.Combine(root,"blocked-status.json"),System.Diagnostics.Process.GetCurrentProcess().Id.ToString(),new string('a',32)});
            Check(blocked==1&&Launcher.Hash(Active())==activeBefore,"concurrent launcher/update gate rejects activation without recovery or spawning");
        }
        var ui=Resource("scripts/ui.gdc","code_ui","UI two");string m2=Manifest("0.7.1",new[]{ui,b,c,alias});
        var plan=Grouped.Plan(root,m2);Check(plan.bytes==ui.download_size&&plan.assets.SequenceEqual(new[]{ui.asset}),"one UI change downloads only the changed resource");
        Cache(ui);Check(Grouped.Plan(root,m2).bytes==0,"verified download reused after cancel/retry");
        File.AppendAllText(Path.Combine(Grouped.Cache(root),"downloads",ui.asset),"corrupt");Check(Grouped.Plan(root,m2).bytes==ui.download_size,"corrupt cache is scheduled again");Cache(ui);
        string old=Launcher.Hash(Active());Grouped.Fault=p=>{if(p=="assembled:code_ui")throw new IOException("interrupted merge");};
        Throws(()=>Grouped.Activate(root,m2,Guid.NewGuid().ToString("N")),"merge interruption before activation");Grouped.Fault=null;Check(Launcher.Hash(Active())==old,"merge interruption leaves old pointer intact");
        bool rebuiltBase=false;Grouped.Fault=p=>{if(p=="assembled:base")rebuiltBase=true;};Grouped.Assemble(root,m2);Grouped.Fault=null;
        Check(!rebuiltBase,"duplicate content aliases do not rebuild unchanged groups");
        Grouped.Activate(root,m2,Guid.NewGuid().ToString("N"));Check(Grouped.Recover(root),"exit/power-loss after pointer change recovered");Check(Launcher.Hash(Active())==old,"recovery restores old manifest");Saves();
        Grouped.Activate(root,m2,Guid.NewGuid().ToString("N"));Check(Grouped.Confirm(root,new string[0]),"healthy new process commits groups");System.Threading.Thread.Sleep(1800);
        var model=Resource("assets/model.scn","maps","model two");string m3=Manifest("0.7.2",new[]{ui,b,model,alias});
        Check(Grouped.Plan(root,m3).bytes==model.download_size,"consecutive model change only downloads model");Cache(model);
        Grouped.Activate(root,m3,Guid.NewGuid().ToString("N"));Check(!Grouped.Confirm(root,new[]{"--fail"}),"unhealthy child rolls back");Check(Grouped.Validate(Active()).version=="0.7.1","failed update keeps previous playable version");Saves();
        File.Copy(m1,Active(),true);Cache(ui);Cache(model);
        Check(Grouped.Plan(root,m3).bytes==0,"cross-version update reuses both already verified files");
        Grouped.Activate(root,m3,Guid.NewGuid().ToString("N"));Check(Grouped.Confirm(root,new string[0]),"cross-version activation uses one complete target snapshot");System.Threading.Thread.Sleep(1800);
        var current=Grouped.Validate(Active());string basePack=Grouped.Pack(root,"base",current.files.Where(f=>f.group=="base"));File.Delete(basePack);
        Check(Grouped.Plan(root,m3).bytes==b.download_size,"same-version repair detects missing group");Cache(b);Grouped.Assemble(root,m3);Check(Grouped.Plan(root,m3).bytes==0,"missing group repaired without other resources");
        File.WriteAllText(basePack,"damaged zip");Check(Grouped.Plan(root,m3).bytes==0,"verified cache repairs corrupt installed group without downloading");Grouped.Assemble(root,m3);Check(Grouped.LocalSources(root).Count==3,"repair reconstructs valid groups");
        var bad=Grouped.Read<GroupManifest>(m3);bad.files[0].path="../_玩家数据/save_1.json";string hostile=Path.Combine(root,"hostile.json");Grouped.Write(hostile,bad);Throws(()=>Grouped.Validate(hostile),"traversal manifest rejected");
        bad=Grouped.Read<GroupManifest>(m3);bad.files[0].group="unknown";Grouped.Write(hostile,bad);Throws(()=>Grouped.Validate(hostile),"unknown group rejected");
        bad=Grouped.Read<GroupManifest>(m3);bad.baseline=new string('0',64);Grouped.Write(hostile,bad);Throws(()=>Grouped.Plan(root,hostile),"incompatible engine/bootstrap rejected");
        Check(Directory.GetFiles(Path.Combine(Grouped.Runtime(root),"packs"),"*.zip").Length<=6,"compaction bounds packs to active + previous groups");Saves();
        string origin="https://github.com/sabrina1647412733-collab/anomaly-bureau-game/releases/download/v0.8.2/";
        Check(Grouped.AssetUri(origin,"AnomalyBureau-resources-base.bin","0.8.0").AbsoluteUri=="https://github.com/sabrina1647412733-collab/anomaly-bureau-game/releases/download/v0.8.0/AnomalyBureau-resources-base.bin","unchanged resources resolve against their original release");
        Throws(()=>Grouped.AssetUri(origin,"AnomalyBureau-resources-base.bin","../evil"),"source version traversal rejected");
        Throws(()=>Grouped.AssetUri("https://github.com/foreign/repo/releases/download/v0.8.2/","AnomalyBureau-resources-base.bin","0.8.0"),"foreign repository rejected");
        var sourceManifest=Grouped.Read<GroupManifest>(m3); sourceManifest.transport=3;
        foreach(var f in sourceManifest.files) {f.bundle="AnomalyBureau-resources-"+f.group+".bin";f.offset=0;f.source_version="0.7.0";}
        sourceManifest.containers=sourceManifest.files.Select(f=>new ResourceContainer{version="0.7.0",name=f.bundle,size=1000000,sha256=new string('a',64)}).GroupBy(container=>container.name).Select(g=>g.First()).ToArray();
        Grouped.Write(hostile,sourceManifest); Check(Grouped.Validate(hostile).transport==3,"cross-release transport keeps compatible runtime layout");
        sourceManifest.files[0].source_version="9.0.0";Grouped.Write(hostile,sourceManifest);Throws(()=>Grouped.Validate(hostile),"missing historical source rejected");
        sourceManifest.files[0].source_version="0.7.0";sourceManifest.files[0].offset=1000001;Grouped.Write(hostile,sourceManifest);Throws(()=>Grouped.Validate(hostile),"out-of-container resource range rejected");
        sourceManifest.files[0].offset=0;Grouped.Write(hostile,sourceManifest);string beforeSourceSwitch=Launcher.Hash(Active());
        Grouped.Activate(root,hostile,Guid.NewGuid().ToString("N"));Check(Grouped.Recover(root)&&Launcher.Hash(Active())==beforeSourceSwitch,"interrupted cross-release activation restores previous manifest");
        Grouped.Activate(root,hostile,Guid.NewGuid().ToString("N"));Check(!Grouped.Confirm(root,new[]{"--fail"})&&Launcher.Hash(Active())==beforeSourceSwitch,"cross-release startup failure rolls back with historical sources intact");Saves();
        Console.WriteLine("RESULT "+passed+" passed, "+failed+" failed");return failed==0?0:1;
    }
}
