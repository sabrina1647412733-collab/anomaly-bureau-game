using System;
using System.IO;
using System.Linq;
using System.Diagnostics;
using AnomalyBureauDistribution;
class MigrationTests {
    static string root,stage,fixture;static int passed,failed;
    static void Check(bool b,string s){Console.WriteLine((b?"PASS ":"FAIL ")+s);if(b)passed++;else failed++;}
    static void Setup() {
        if(Directory.Exists(root))Directory.Delete(root,true);
        Directory.CreateDirectory(root);Directory.CreateDirectory(Path.Combine(root,"_玩家数据"));
        File.WriteAllText(Path.Combine(root,"_玩家数据","save_1.json"),"saved");File.WriteAllText(Path.Combine(root,"_玩家数据","settings.cfg"),"settings");
        File.Copy(fixture,Path.Combine(root,"AnomalyBureau.Game.exe"));File.WriteAllText(Path.Combine(root,"AnomalyBureau.Game.pck"),"old-pck");File.WriteAllText(Path.Combine(root,"AnomalyBureau.exe"),"old-launcher");
        stage=Path.Combine(root,"_更新缓存","migration","stage");Directory.CreateDirectory(Path.Combine(stage,"_运行文件"));
        File.Copy(fixture,Path.Combine(stage,"AnomalyBureau.Game.exe"));File.WriteAllText(Path.Combine(stage,"AnomalyBureau.Game.pck"),"new-boot");File.WriteAllText(Path.Combine(stage,"AnomalyBureau.exe"),"new-launcher");
        Grouped.Write(Path.Combine(stage,"_运行文件","active.json"),new GroupManifest{protocol=2,version="0.7.0",baseline=new string('a',64),files=new[]{new ResourceFile{path="scripts/ui.gdc",group="code_ui",size=1,sha256=new string('b',64),asset="r-"+new string('b',64)+".zip",download_size=2,download_sha256=new string('c',64)}}});
        var names=new[]{"AnomalyBureau.exe","AnomalyBureau.Game.exe","AnomalyBureau.Game.pck","_运行文件/active.json","Godot-LICENSE.txt"};File.WriteAllText(Path.Combine(stage,"Godot-LICENSE.txt"),"license");
        Grouped.Write(Path.Combine(stage,"layout.json"),new Layout{protocol=1,files=names.Select(p=>new PayloadFile{path=p,size=new FileInfo(Path.Combine(stage,p)).Length,sha256=Launcher.Hash(Path.Combine(stage,p))}).ToArray()});
    }
    static int Install(string suffix){return Migration.Install(new[]{"--migrate-install",root,stage,Path.Combine(root,"result-"+suffix+".json"),Process.GetCurrentProcess().Id.ToString()});}
    static void Old(string label){Check(File.ReadAllText(Path.Combine(root,"AnomalyBureau.Game.pck"))=="old-pck"&&File.ReadAllText(Path.Combine(root,"AnomalyBureau.exe"))=="old-launcher"&&!File.Exists(Path.Combine(root,"_运行文件","active.json")),label+" restores fixed launcher, playable PCK and old layout");Check(File.ReadAllText(Path.Combine(root,"_玩家数据","save_1.json"))=="saved"&&File.ReadAllText(Path.Combine(root,"_玩家数据","settings.cfg"))=="settings",label+" preserves player data");}
    public static int Main(string[] args){root=Path.GetFullPath(args[0]);fixture=args[1];if(!Path.GetFileName(root).StartsWith("sandbox-"))return 9;
        Setup();Check(Install("healthy")==0,"healthy native migration commits");System.Threading.Thread.Sleep(1800);
        foreach(string point in new[]{"AnomalyBureau.exe","AnomalyBureau.Game.pck","_运行文件/active.json"}){
            Setup();Migration.Fault=p=>{if(p=="replaced:"+point)throw new IOException("injected migration interruption");};
            Check(Install("fault")==1,"replacement failure handled at "+point);Migration.Fault=null;Old(point);System.Threading.Thread.Sleep(3800);
        }
        Setup();File.WriteAllText(Path.Combine(stage,"AnomalyBureau.Game.pck"),"corrupt");Check(Install("corrupt")==1,"corrupt migration payload rejected");Old("corrupt stage");System.Threading.Thread.Sleep(3800);
        Console.WriteLine("RESULT "+passed+" passed, "+failed+" failed");return failed==0?0:1;
    }
}
