unit FunctionPfd;
{$mode objfpc}{$H+}

interface
procedure Main;

implementation
uses
  RaspberryPi2, {Include RaspberryPi2 to make sure all standard functions are included}
  BCM2836,BCM2709,
  GlobalConst,
  GlobalTypes,
  Threads,
  Console,
  Platform,
  Ultibo,
  SysUtils,
  FATFS,FileSystem,MMC,
  OpenVG,       {Include the OpenVG unit so we can use the various types and structures}
  VGShapes,     {Include the VGShapes unit to give us access to all the functions}
  VC4,
  artihorizon,          {Include the VC4 unit to enable access to the GPU}
  Shared;

var
 Width:Integer;  {A few variables used by our shapes example}
 Height:Integer;
 

 ArtiHoriX:Integer;
 ArtiHoriY:Integer;
 ArtiHorisize:Integer;

 yawangle:Integer;
 rollangle:Integer;
 pitchangle:Integer;

 WindowHandle:TWindowHandle;

procedure Main; 
begin
 WindowHandle:=ConsoleWindowCreateOrReuse(WindowHandle,ConsoleDeviceGetDefault,CONSOLE_POSITION_FULL,True);

 ConsoleWindowWriteLn(WindowHandle,'Starting PFD Demo');

 Width:=ConsoleWindowGetWidth(WindowHandle);
 Height:=ConsoleWindowGetHeight(WindowHandle);

 {Initialize OpenVG and the VGShapes unit}
 VGShapesInit(Width,Height); 
 
 {set some values for testing}

 ArtiHoriX:=500;
 ArtiHoriY:=500;
 ArtiHorisize:=300;
 yawangle:=0;
 rollangle:=10;
 pitchangle:=10;
 
 {Start a picture the full width and height of the screen}
 VGShapesStart(Width,Height);
 
 {Make the background black}
 VGShapesBackground(0,0,0);

 {add PFD instruments}

 while not QuitRequested do
   begin
     horizon(ArtiHoriX, ArtiHoriY, ArtiHorisize, yawangle, rollangle, pitchangle);
     rollangle:= rollangle + 1;
     {End our picture and render it to the screen}
     VGShapesEnd;
     Sleep(100);
   end;

 {Clear our screen, cleanup OpenVG and deinitialize VGShapes}
 VGShapesFinish;
 
// {VGShapes calls BCMHostInit during initialization, we should also call BCMHostDeinit to cleanup}
// BCMHostDeinit;
// 
// ConsoleWindowWriteLn(WindowHandle,'Completed VGShapes Demo');
end;

initialization
 WindowHandle:=TWindowHandle(Nil);
end.
