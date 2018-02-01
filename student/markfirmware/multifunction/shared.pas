unit Shared;
{$mode objfpc}{$H+}

interface
uses
 GlobalTypes,
 Console;
function ConsoleWindowCreateOrReuse(WindowHandle:TWindowHandle;ConsoleDevice:PConsoleDevice;Position:LongWord;B:Boolean):TWindowHandle;
function QuitRequested:Boolean;

implementation
uses
 GlobalConfig,
 GlobalConst,
 Platform,
 Threads,
 SysUtils,
 Classes,
 Ultibo,
 Logging,
 Keyboard;

function ConsoleWindowCreateOrReuse(WindowHandle:TWindowHandle;ConsoleDevice:PConsoleDevice;Position:LongWord;B:Boolean):TWindowHandle;
begin
 if Pointer(WindowHandle) = Nil then
  WindowHandle:=ConsoleWindowCreate(ConsoleDeviceGetDefault,Position,B)
 else
  ConsoleWindowSetDefault(ConsoleDeviceGetDefault,WindowHandle);
 Result:=WindowHandle;
end;

function QuitRequested:Boolean;
var
 Key:Char;
begin
 Result:=ConsolePeekKey(Key,Nil);
 if Result then
  begin
   ConsoleGetKey(Key,Nil);
   if Key = 'r' then
    SystemRestart(0);
  end;
end;

end.
