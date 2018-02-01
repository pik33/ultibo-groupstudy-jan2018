unit FunctionCecDemo;
{$mode objfpc}{$H+}

interface
procedure Main;

implementation
uses
 GlobalConfig,
 GlobalConst,
 GlobalTypes,
 Platform,
 Threads,
 SysUtils,
 Classes,
 Ultibo,
 Logging,
 Console,
 VC4CEC,
 VC4,
 Shared;

var
 WindowHandle:TWindowHandle;

procedure StartLogging;
begin
 LOGGING_INCLUDE_COUNTER:=False;
 CONSOLE_REGISTER_LOGGING:=True;
 LoggingConsoleDeviceAdd(ConsoleDeviceGetDefault);
 LoggingDeviceSetDefault(LoggingDeviceFindByType(LOGGING_TYPE_CONSOLE));
end;

procedure Log(Message:String);
begin
 LoggingOutput(Message);
end;

function Swap(const A:cardinal): cardinal; inline;
begin
 result := ((A And $ff) shl 24) + ((A and $ff00) shl 8) + ((A and $ff0000) shr 8) + ((A and $ff000000) shr 24);
end;

procedure CECCallback(Data:Pointer; Reason, Param1, Param2, Param3, Param4 :LongWord); cdecl;
begin
 Param1:=Swap(Param1);
 Param2:=Swap(Param2);
 Param3:=Swap(Param3);
 Param4:=Swap(Param4);
 if (Reason and $ffff) = VC_CEC_BUTTON_PRESSED then
  Log(Format('pressed %s',[UserControlToString((Param1 shr 8) and $ff)]))
 else if (Reason and $ffff) = VC_CEC_BUTTON_RELEASE then
  Log(Format('release %s',[UserControlToString((Param1 shr 8) and $ff)]))
 else
  Log (format ('Callback Reason %4.4x Params %.8x %.8x %.8x %.8x %s', [Reason And $ffff,Param1,Param2,Param3,Param4,ReasonToString(Reason and $ff)]));
end;

procedure Main;
begin
 WindowHandle:=ConsoleWindowCreate(ConsoleDeviceGetDefault,CONSOLE_POSITION_FULL,True);
 StartLogging;
 BCMHostInit;
 vc_cec_set_passive(True);
 vc_cec_register_callback(@CECCallback,Nil);
 vc_cec_register_all;
 while not QuitRequested do
  begin
  end;
end;

end.
