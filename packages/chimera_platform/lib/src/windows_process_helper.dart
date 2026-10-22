/// Fixed helper code; caller data arrives as JSON on stdin, never as shell code.
/// The child starts suspended, joins a kill-on-close job, then resumes. Descendants
/// remain in that job even after their original parent has exited.
const windowsProcessHelper = r'''
$ErrorActionPreference = 'Stop'
# Keep encoded bootstrap progress out of the tool's stderr stream.
$ProgressPreference = 'SilentlyContinue'
try {
 $request = [Console]::In.ReadLine() | ConvertFrom-Json
 Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Runtime.InteropServices;
public static class ChimeraOwnedProcess {
 [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct STARTUPINFO {
  public int cb; public string reserved,desktop,title;
  public int x,y,xSize,ySize,xChars,yChars,fill,flags;
  public short show,reservedSize; public IntPtr reservedPtr,input,output,error;
 }
 [StructLayout(LayoutKind.Sequential)] struct PROCESS_INFORMATION { public IntPtr process,thread; public uint id,threadId; }
 [StructLayout(LayoutKind.Sequential)] struct BASIC_LIMIT { public long processTime,jobTime; public uint flags; public UIntPtr min,max; public uint active; public UIntPtr affinity; public uint priority,scheduling; }
 [StructLayout(LayoutKind.Sequential)] struct IO_COUNTERS { public ulong readOps,writeOps,otherOps,readBytes,writeBytes,otherBytes; }
 [StructLayout(LayoutKind.Sequential)] struct EXTENDED_LIMIT { public BASIC_LIMIT basic; public IO_COUNTERS io; public UIntPtr processMemory,jobMemory,peakProcess,peakJob; }
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool CreateProcess(string app,StringBuilder command,IntPtr pa,IntPtr ta,bool inherit,uint flags,IntPtr env,string cwd,ref STARTUPINFO startup,out PROCESS_INFORMATION info);
 [DllImport("kernel32.dll")] static extern uint ResumeThread(IntPtr thread);
 [DllImport("kernel32.dll")] static extern bool TerminateProcess(IntPtr process,uint code);
 [DllImport("kernel32.dll")] static extern bool GetExitCodeProcess(IntPtr process,out uint code);
 [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr handle,uint milliseconds);
 [DllImport("kernel32.dll")] static extern IntPtr CreateJobObject(IntPtr attributes,string name);
 [DllImport("kernel32.dll")] static extern bool SetInformationJobObject(IntPtr job,int kind,ref EXTENDED_LIMIT info,uint size);
 [DllImport("kernel32.dll")] static extern bool AssignProcessToJobObject(IntPtr job,IntPtr process);
 [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
 [DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int kind);
 [DllImport("kernel32.dll")] static extern bool SetHandleInformation(IntPtr handle,uint mask,uint flags);
 static string Resolve(string executable) {
  if(Path.IsPathRooted(executable) || executable.IndexOfAny(new[]{'\\','/'})>=0) return Path.GetFullPath(executable);
  foreach(string directory in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(';')) {
   string candidate=Path.Combine(directory.Trim('"'),executable);
   if(File.Exists(candidate)) return candidate;
   if(File.Exists(candidate+".exe")) return candidate+".exe";
  }
  throw new FileNotFoundException();
 }
 // Quote according to the Windows argv backslash/quote rules, including trailing
 // backslashes before the closing quote. No cmd.exe/PowerShell interpolation.
 static string Quote(string value) {
  StringBuilder result=new StringBuilder("\""); int backslashes=0;
  foreach(char c in value) {
   if(c=='\\') { backslashes++; continue; }
   if(c=='"') { result.Append('\\',backslashes*2+1); result.Append(c); }
   else { result.Append('\\',backslashes); result.Append(c); }
   backslashes=0;
  }
  result.Append('\\',backslashes*2); result.Append('"'); return result.ToString();
 }
 public static int Run(string executable,string[] args,string cwd) {
  IntPtr job=IntPtr.Zero; PROCESS_INFORMATION process=new PROCESS_INFORMATION(); bool completed=false;
  try {
   job=CreateJobObject(IntPtr.Zero,null); EXTENDED_LIMIT limit=new EXTENDED_LIMIT(); limit.basic.flags=0x2000;
   if(job==IntPtr.Zero || !SetInformationJobObject(job,9,ref limit,(uint)Marshal.SizeOf(limit))) throw new InvalidOperationException();
   STARTUPINFO startup=new STARTUPINFO(); startup.cb=Marshal.SizeOf(startup); startup.flags=0x100;
   startup.input=GetStdHandle(-10); startup.output=GetStdHandle(-11); startup.error=GetStdHandle(-12);
   if(!SetHandleInformation(startup.input,1,1) || !SetHandleInformation(startup.output,1,1) || !SetHandleInformation(startup.error,1,1)) throw new InvalidOperationException();
   string path=Resolve(executable); StringBuilder command=new StringBuilder(Quote(path));
   foreach(string argument in args) command.Append(" "+Quote(argument));
   if(!CreateProcess(path,command,IntPtr.Zero,IntPtr.Zero,true,0x08000004,IntPtr.Zero,cwd,ref startup,out process)) throw new InvalidOperationException();
   if(!AssignProcessToJobObject(job,process.process) || ResumeThread(process.thread)==UInt32.MaxValue) throw new InvalidOperationException();
   if(WaitForSingleObject(process.process,UInt32.MaxValue)!=0) throw new InvalidOperationException();
   uint code; if(!GetExitCodeProcess(process.process,out code)) throw new InvalidOperationException(); completed=true;
   return unchecked((int)code);
  } finally {
   if(!completed && process.process!=IntPtr.Zero) TerminateProcess(process.process,127);
   if(process.thread!=IntPtr.Zero) CloseHandle(process.thread);
   if(process.process!=IntPtr.Zero) CloseHandle(process.process);
   // Normal completion also cleans detached descendants left by the tool.
   if(job!=IntPtr.Zero) CloseHandle(job);
  }
 }
}
'@
 $status = [ChimeraOwnedProcess]::Run([string]$request.executable,[string[]]$request.arguments,[string]$request.workingDirectory)
 exit $status
} catch {
 [Console]::Error.WriteLine('Native process launch failed.')
 exit 127
}
''';
