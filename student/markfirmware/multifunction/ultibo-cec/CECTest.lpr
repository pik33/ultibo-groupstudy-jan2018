program CECTest;

{$mode objfpc}{$H+}
{$define use_tftp}
uses
  RaspberryPi3,
  GlobalConfig,
  GlobalConst,
  GlobalTypes,
  Platform,
  Threads,
  SysUtils,
  Classes,
  Ultibo, Console,
{$ifdef use_tftp}
  uTFTP, Winsock2,
{$endif}
  VC4, VC4CEC
  { Add additional units here };

var
  Console1 : TWindowHandle;
{$ifdef use_tftp}
  IPAddress : string;
{$endif}
  Top : VC_CEC_TOPOLOGY_T;
  res : integer;
  ch : char;
  i : integer;
  id : LongWord;
  b : byte;
  w : word;
  s : string;
  cecmsg : TVC_CEC_MESSAGE;

procedure Log (s : string);
begin
  ConsoleWindowWriteLn (Console1, s);
end;

procedure Msg (Sender : TObject; s : string);
begin
  Log ('TFTP : ' + s);
end;

{$ifdef use_tftp}
function WaitForIPComplete : string;
var
  TCP : TWinsock2TCPClient;
begin
  TCP := TWinsock2TCPClient.Create;
  Result := TCP.LocalAddress;
  if (Result = '') or (Result = '0.0.0.0') or (Result = '255.255.255.255') then
    begin
      while (Result = '') or (Result = '0.0.0.0') or (Result = '255.255.255.255') do
        begin
          sleep (1000);
          Result := TCP.LocalAddress;
        end;
    end;
  TCP.Free;
end;
{$endif}

procedure WaitForSDDrive;
begin
  while not DirectoryExists ('C:\') do sleep (500);
end;
(*
  On Panasonic to enable media control buttons on bottom of the remote,
  you may have to change the operation mode.
  To change it, press bottom Power-button, keep it pressed, and press 7 3 Stop.
  After releasing Power-button, Play, Pause, etc should work in XBMC.
*)

(*
 * Callback reason and arguments (for sending back to host) All parameters are uint32_t
 * For the reason parameter
 * Bit 15-0 of reason is the reason code,
 * Bit 23-16 is length of valid bytes which follows in the 4 32-bit parameters (0 < length <= 16)
 * Bit 31-24 is any return code (if required for this callback)
 *
 * Length of valid bytes for TX/RX/button press/release callbacks will be the length
 * of the actual CEC message
 *
 * Length of valid bytes for logical address will always be 6 (first parameter + 16-bit physical address)
 *
 * Length of valid bytes for topology callback will always be 2 (16-bit mask)
 *
 * Many CEC callback messages are of variable length so not all bytes 0-15 are available
 *
 * Reason                  param1          param2       param3      param4           remark
 * VC_CEC_TX               bytes 0-3       bytes 4-7    bytes 8-11  bytes 12-15      A message has been transmitted
 *                                                                                   Only a message sent from the host will
                                                                                     generate this callback
                                                                                     (non-zero return code means failure)

 * VC_CEC_RX               bytes 0-3       bytes 4-7    bytes 8-11  bytes 12-15      By definition only successful message will be forwarded
 *
 * VC_CEC_BUTTON_PRESSED   bytes 0-3       bytes 4-7     -           -               User Control pressed (byte 2 will be actual user control code)
 * VC_CEC_BUTTON_RELEASE   bytes 0-3          -          -           -               User Control release (byte 2 will be actual user control code)

 * VC_CEC_REMOTE_PRESSED   bytes 0-3       bytes 4-7    bytes 8-11  bytes 12-15      Vendor remote button down
 * VC_CEC_REMOTE_RELEASE   bytes 0-3       bytes 4-7    bytes 8-11  bytes 12-15      Vendor remote button up

 * VC_CEC_LOGICAL_ADDR     Log addr        Phy addr      -           -               Logical address allocated or failure
 * VC_CEC_TOPOLOGY         topology bit
 *                         mask                                                      New topology is avaiable
 *
 * VC_CEC_LOGICAL_ADDR_LOST Last log addr   Phy addr                                  "Last log addr" is no longer available
 *
 * Notes:
 * VC_CEC_BUTTON_RELEASE and VC_CEC_REMOTE_RELEASE (<User Control Release> and <Vendor Remote Button Up> messages respectively)
 * returns the code from the most recent <User Control pressed> <Vendor Remote button up> respectively.
 * The host application will need to find out the vendor ID of the initiator
 * separately in the case if <Vendor Remote Button Up>/<Vendor Remote Button Down> commands were received.
 * <User Control Pressed> will not be longer than 6 bytes (including header)
 *
 * VC_CEC_LOGICAL_ADDR returns 0xF in param1 whenever no logical address is in used. If physical address is 0xFFFF,
 * this means CEC is being disabled. Otherwise physical address is the one read from EDID (and no suitable logical address
 * is avaiable to be allocated). Host application should only attempt to send message if both param1 is not 0xF AND param2
 * is not 0xFFFF.
 *
 * VC_CEC_TOPOLOGY returns a 16-bit mask in param1 where bit n is set if logical address n is present. Host application
 * must explicitly retrieve the entire topology if it wants to know how devices are connected. The bit mask includes our
 * own logical address.
 *
 * If CEC is running in passive mode, the host will get a VC_CEC_LOGICAL_ADDR_LOST callback if the logical address is
 * lost (e.g. HDMI mode change). In this case the host should try a new logical address. The physical address returned may
 * also change, so the host should check this.
 *)

(*

void CRPiCECAdapterCommunication::OnDataReceived(uint32_t header, uint32_t p0, uint32_t p1, uint32_t p2, uint32_t p3)
{
  {
    CLockObject lock(m_mutex);
    if (m_bDisableCallbacks)
      return;
  }

  VC_CEC_NOTIFY_T reason = (VC_CEC_NOTIFY_T)CEC_CB_REASON(header);

#ifdef CEC_DEBUGGING
  LIB_CEC->AddLog(CEC_LOG_DEBUG, "received data: header:%08X p0:%08X p1:%08X p2:%08X p3:%08X reason:%x", header, p0, p1, p2, p3, reason);
#endif

  switch (reason)
  {
  case VC_CEC_RX:
    // CEC data received
    {
      // translate into a VC_CEC_MESSAGE_T
      VC_CEC_MESSAGE_T message;
      vc_cec_param2message(header, p0, p1, p2, p3, &message);

      // translate to a cec_command
      cec_command command;
      cec_command::Format(command,
          (cec_logical_address)message.initiator,
          (cec_logical_address)message.follower,
          (cec_opcode)CEC_CB_OPCODE(p0));

      // copy parameters
      for (uint8_t iPtr = 1; iPtr < message.length; iPtr++)
        command.PushBack(message.payload[iPtr]);

      // send to libCEC
      m_callback->OnCommandReceived(command);
    }
    break;
  case VC_CEC_TX:
    {
      // handle response to a command that was sent earlier
      m_queue->MessageReceived((cec_opcode)CEC_CB_OPCODE(p0), (cec_logical_address)CEC_CB_INITIATOR(p0), (cec_logical_address)CEC_CB_FOLLOWER(p0), CEC_CB_RC(header));
    }
    break;
  case VC_CEC_BUTTON_PRESSED:
  case VC_CEC_REMOTE_PRESSED:
    {
      // translate into a cec_command
      cec_command command;
      cec_command::Format(command,
                          (cec_logical_address)CEC_CB_INITIATOR(p0),
                          (cec_logical_address)CEC_CB_FOLLOWER(p0),
                          reason == VC_CEC_BUTTON_PRESSED ? CEC_OPCODE_USER_CONTROL_PRESSED : CEC_OPCODE_VENDOR_REMOTE_BUTTON_DOWN);
      command.parameters.PushBack((uint8_t)CEC_CB_OPERAND1(p0));

      // send to libCEC
      m_callback->OnCommandReceived(command);
    }
    break;
  case VC_CEC_BUTTON_RELEASE:
  case VC_CEC_REMOTE_RELEASE:
    {
      // translate into a cec_command
      cec_command command;
      cec_command::Format(command,
                          (cec_logical_address)CEC_CB_INITIATOR(p0),
                          (cec_logical_address)CEC_CB_FOLLOWER(p0),
                          reason == VC_CEC_BUTTON_PRESSED ? CEC_OPCODE_USER_CONTROL_RELEASE : CEC_OPCODE_VENDOR_REMOTE_BUTTON_UP);
      command.parameters.PushBack((uint8_t)CEC_CB_OPERAND1(p0));

      // send to libCEC
      m_callback->OnCommandReceived(command);
    }
    break;
  case VC_CEC_LOGICAL_ADDR:
    {
      CLockObject lock(m_mutex);
      m_previousLogicalAddress = m_logicalAddress;
      if (CEC_CB_RC(header) == VCHIQ_SUCCESS)
      {
        m_bLogicalAddressChanged = true;
        m_logicalAddress = (cec_logical_address)(p0 & 0xF);
        m_bLogicalAddressRegistered = true;
        LIB_CEC->AddLog(CEC_LOG_DEBUG, "logical address changed to %s (%x)", LIB_CEC->ToString(m_logicalAddress), m_logicalAddress);
      }
      else
      {
        m_logicalAddress = CECDEVICE_FREEUSE;
        LIB_CEC->AddLog(CEC_LOG_DEBUG, "failed to change the logical address, reset to %s (%x)", LIB_CEC->ToString(m_logicalAddress), m_logicalAddress);
      }
      m_logicalAddressCondition.Signal();
    }
    break;
  case VC_CEC_LOGICAL_ADDR_LOST:
    {
      LIB_CEC->AddLog(CEC_LOG_DEBUG, "logical %s (%x) address lost", LIB_CEC->ToString(m_logicalAddress), m_logicalAddress);
      // the logical address was taken by another device
      cec_logical_address previousAddress = m_logicalAddress == CECDEVICE_FREEUSE ? m_previousLogicalAddress : m_logicalAddress;
      m_logicalAddress = CECDEVICE_UNKNOWN;

      // notify libCEC that we lost our LA when the connection was initialised
      bool bNotify(false);
      {
        CLockObject lock(m_mutex);
        bNotify = m_bInitialised && m_bLogicalAddressRegistered;
      }
      if (bNotify)
        m_callback->HandleLogicalAddressLost(previousAddress);
    }
    break;
  case VC_CEC_TOPOLOGY:
    break;
  default:
    LIB_CEC->AddLog(CEC_LOG_DEBUG, "ignoring unknown reason %x", reason);
    break;
  }
}*)

procedure CECCallback (Data : pointer; Reason, Param1, Param2, Param3, Param4 : LongWord); cdecl;
var
  amsg : TVC_CEC_MESSAGE;
  res : integer;
begin
  if Data = nil then begin end;
  Log ('Callback Reason ' + ReasonToString (Reason and $ffff));
  Log (format ('Call Back Params %.8x %.8x %.8x %.8x', [Param1, Param2, Param3, Param4]));
  case Reason and $ffff of
    VC_CEC_TX :
      begin
        amsg.len := 0;
        res := vc_cec_param2message (Reason, Param1, Param2, Param3, Param4, amsg);
        Log ('Convert Result ' + CECErrToString (res) + ' Initiator ' + amsg.initiator.ToHexString(1) + '  Follower ' + amsg.follower.ToHexString(1));
        s := '';
        if amsg.len > 0 then s := 'OpCode ' + OpCodeToString (amsg.payload[0]) + ' ';
        s := s + 'Playload';
        for i := 0 to amsg.len - 1 do s := s + ' ' + amsg.payload[i].ToHexString (2);
        Log (s);
         end;
    VC_CEC_RX :
      begin
        amsg.len := 0;
        res := vc_cec_param2message (Reason, Param1, Param2, Param3, Param4, amsg);
        Log ('Convert Result ' + CECErrToString (res) + ' Initiator ' + amsg.initiator.ToHexString(1) + '  Follower ' + amsg.follower.ToHexString(1));
        if amsg.len > 0 then s := 'OpCode ' + OpCodeToString (amsg.payload[0]) + ' ';
        s := s + 'Playload';
        for i := 0 to amsg.len - 1 do s := s + ' ' + amsg.payload[i].ToHexString (2);
        Log (s);
      end;
    VC_CEC_BUTTON_PRESSED : ;
    VC_CEC_BUTTON_RELEASE : ;
    VC_CEC_REMOTE_PRESSED : ;
    VC_CEC_REMOTE_RELEASE : ;
    VC_CEC_LOGICAL_ADDR : ;
    VC_CEC_TOPOLOGY : ;
    VC_CEC_LOGICAL_ADDR_LOST : ;
    end;
end;

begin
  Console1 := ConsoleWindowCreate (ConsoleDeviceGetDefault, CONSOLE_POSITION_FULLSCREEN, true);
  WaitForSDDrive;
  Log ('CEC Test');
{$ifdef use_tftp}
  IPAddress := WaitForIPComplete;
  Log ('TFTP : Usage tftp -i ' + IPAddress + ' PUT kernel7.img');
  SetOnMsg (@Msg);
  Log ('');
{$endif}
  ch := #0;
  Top.num_devices := 0;
  BCMHostInit;
  vc_cec_set_passive (true);
  vc_cec_register_callback (@CECCallback,  nil);
  vc_cec_register_all;
  while true do
    begin
      if ConsoleGetKey (ch, nil) then
        case (UpperCase (ch)) of
          '1' :
            begin
              FillChar (Top, SizeOf (Top), 0);
              res := vc_cec_get_topology (Top);
              Log ('Topology - Result ' + CECErrToString (res));
              Log ('Num Devices ' + Top.num_devices.ToString);
              for i := 0 to Top.num_devices - 1 do
                begin
                  Log ('Device ' + i.ToString);
                  Log ('  Logical Address          : ' + LogAddrToString (Top.device_attr[i] and $0f));
                  Log ('  Device Type              : ' + DevTypeToString ((Top.device_attr[i] shr 4) and $0f));
                  Log ('  Index to upstream device : ' + IntToStr ((Top.device_attr[i] shr 8) and $0f));
                  Log ('  No. downstream devices   : ' + IntToStr ((Top.device_attr[i] shr 12) and $0f));
                end;
            end;
          '2' :
            begin
              res := vc_cec_register_all;
              Log ('Register All - Result ' + CECErrToString (res));
            end;
          '3' :
            begin
              id := $100;
              res := vc_cec_get_vendor_id (1, id);
              Log ('Get Vendor ID - Result ' + CECErrToString (res)+ ' ID ' + id.ToString);
            end;
          '4' :
            begin
              b := vc_cec_device_type (1);
              Log ('Device Type of 1 is ' + DevTypeToString (b));
            end;
          '5' :
            begin
              w := 0;
              res := vc_cec_get_physical_address (w);
              Log ('Physical Address - Result ' + CECErrToString (res)+ ' is ' + PhysAddrToString (w));
            end;
          '6' :
            begin
              res := vc_cec_send_Standby ($f, true);  // send all to standby
              Log ('All standby - Result ' + CECErrToString (res));
            end;
          '7' :
            begin
              for i := CEC_AllDevices_eTV to CEC_AllDevices_eUnRegistered do
                begin
                  res := vc_cec_poll_address (i);
                  Log (LogAddrToString (i) + ' - Result ' + CECErrToString (res));
                  sleep (500);
                end;
            end;
          '8' :   // this currently doesn't work
            begin
              cecmsg.initiator := $1;     // me
              cecmsg.follower := 0;       // tv
              cecmsg.len := 3;            // command has 3 bytes
              cecmsg.payload[0] := CEC_Opcode_ActiveSource;
              cecmsg.payload[1] := $10;
              cecmsg.payload[2] := $00;
              res := vc_cec_send_message2 (cecmsg);
              log ('Send Message - Result ' + CECErrToString (res));
            end;
          '9' :
            begin
              cecmsg.initiator := $f;     // unregistered
              cecmsg.follower := 0;       // tv
              cecmsg.len := 1;            // command has 1 byte
              cecmsg.payload[0] := CEC_Opcode_Standby;
              res := vc_cec_send_message2 (cecmsg);
              Log ('Send Message - Result ' + CECErrToString (res));
            end;
          '0' :
            begin
              cecmsg.initiator := $f;     // unregistered
              cecmsg.follower := 0;       // tv
              cecmsg.len := 1;            // command has 1 byte
              cecmsg.payload[0] := CEC_Opcode_ImageViewOn;
              res := vc_cec_send_message2 (cecmsg);
              Log ('Send Message - Result ' + CECErrToString (res));
            end;
          'P' :
            begin
              res := vc_cec_set_passive (true);
              Log ('Set Passive - Result ' + CECErrToString (res));
            end;
          'A' :
            begin
              res := vc_cec_set_passive (false);
              Log ('Set Active - Result ' + CECErrToString (res));
            end;

          'C' : ConsoleWindowClear (Console1);
          end;
    end;
  ThreadHalt (0);
end.

