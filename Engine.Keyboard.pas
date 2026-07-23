unit Engine.Keyboard;

interface

uses
  Winapi.Windows,
  System.SysUtils;

type
  TKeyboard = class
  public
    class function KeyCode(const AName: string): Integer; static;
    class function IsKeyPressed(const AKeyCode: Integer): Boolean; overload; static;
    class function IsKeyPressed(const AKeyName: string): Boolean; overload; static;
  end;

function KeyCode(const AName: string): Integer;
function IsKeyPressed(const AKeyCode: Integer): Boolean; overload;
function IsKeyPressed(const AKeyName: string): Boolean; overload;

implementation

function ResolveKeyCode(const AName: string): Integer; forward;

function NormalizeKeyName(const AName: string): string;
begin
  Result := UpperCase(Trim(AName));
  Result := StringReplace(Result, ' ', '', [rfReplaceAll]);
  Result := StringReplace(Result, '_', '', [rfReplaceAll]);
  Result := StringReplace(Result, '-', '', [rfReplaceAll]);
end;

function TryFunctionKeyCode(const AName: string; out AKeyCode: Integer): Boolean;
var
  Index: Integer;
begin
  Result := False;
  AKeyCode := 0;

  if (Length(AName) < 2) or (AName[1] <> 'F') then
    Exit;

  if not TryStrToInt(Copy(AName, 2, MaxInt), Index) then
    Exit;

  Result := (Index >= 1) and (Index <= 24);
  if Result then
    AKeyCode := VK_F1 + Index - 1;
end;

function TryNumpadKeyCode(const AName: string; out AKeyCode: Integer): Boolean;
var
  Index: Integer;
begin
  Result := False;
  AKeyCode := 0;

  if Copy(AName, 1, 6) <> 'NUMPAD' then
    Exit;

  if not TryStrToInt(Copy(AName, 7, MaxInt), Index) then
    Exit;

  Result := (Index >= 0) and (Index <= 9);
  if Result then
    AKeyCode := VK_NUMPAD0 + Index;
end;

function ResolveKeyCode(const AName: string): Integer;
var
  Name: string;
begin
  Name := NormalizeKeyName(AName);
  if Name = '' then
    raise Exception.Create('Keyboard key name cannot be empty');

  if Length(Name) = 1 then
  begin
    if CharInSet(Name[1], ['A'..'Z', '0'..'9']) then
      Exit(Ord(Name[1]));
  end;

  if TryFunctionKeyCode(Name, Result) then
    Exit;
  if TryNumpadKeyCode(Name, Result) then
    Exit;

  if (Name = 'BACKSPACE') or (Name = 'BACK') then
    Result := VK_BACK
  else if Name = 'TAB' then
    Result := VK_TAB
  else if Name = 'CLEAR' then
    Result := VK_CLEAR
  else if (Name = 'ENTER') or (Name = 'RETURN') then
    Result := VK_RETURN
  else if Name = 'SHIFT' then
    Result := VK_SHIFT
  else if (Name = 'CTRL') or (Name = 'CONTROL') then
    Result := VK_CONTROL
  else if Name = 'ALT' then
    Result := VK_MENU
  else if Name = 'PAUSE' then
    Result := VK_PAUSE
  else if Name = 'CAPSLOCK' then
    Result := VK_CAPITAL
  else if (Name = 'ESC') or (Name = 'ESCAPE') then
    Result := VK_ESCAPE
  else if Name = 'SPACE' then
    Result := VK_SPACE
  else if (Name = 'PAGEUP') or (Name = 'PGUP') then
    Result := VK_PRIOR
  else if (Name = 'PAGEDOWN') or (Name = 'PGDN') then
    Result := VK_NEXT
  else if Name = 'END' then
    Result := VK_END
  else if Name = 'HOME' then
    Result := VK_HOME
  else if Name = 'LEFT' then
    Result := VK_LEFT
  else if Name = 'UP' then
    Result := VK_UP
  else if Name = 'RIGHT' then
    Result := VK_RIGHT
  else if Name = 'DOWN' then
    Result := VK_DOWN
  else if (Name = 'INSERT') or (Name = 'INS') then
    Result := VK_INSERT
  else if (Name = 'DELETE') or (Name = 'DEL') then
    Result := VK_DELETE
  else if (Name = 'LEFTWINDOWS') or (Name = 'LWIN') then
    Result := VK_LWIN
  else if (Name = 'RIGHTWINDOWS') or (Name = 'RWIN') then
    Result := VK_RWIN
  else if (Name = 'APPS') or (Name = 'MENU') then
    Result := VK_APPS
  else if Name = 'MULTIPLY' then
    Result := VK_MULTIPLY
  else if Name = 'ADD' then
    Result := VK_ADD
  else if Name = 'SEPARATOR' then
    Result := VK_SEPARATOR
  else if Name = 'SUBTRACT' then
    Result := VK_SUBTRACT
  else if Name = 'DECIMAL' then
    Result := VK_DECIMAL
  else if Name = 'DIVIDE' then
    Result := VK_DIVIDE
  else if Name = 'NUMLOCK' then
    Result := VK_NUMLOCK
  else if Name = 'SCROLLLOCK' then
    Result := VK_SCROLL
  else if (Name = 'LEFTSHIFT') or (Name = 'LSHIFT') then
    Result := VK_LSHIFT
  else if (Name = 'RIGHTSHIFT') or (Name = 'RSHIFT') then
    Result := VK_RSHIFT
  else if (Name = 'LEFTCTRL') or (Name = 'LEFTCONTROL') or (Name = 'LCTRL') then
    Result := VK_LCONTROL
  else if (Name = 'RIGHTCTRL') or (Name = 'RIGHTCONTROL') or (Name = 'RCTRL') then
    Result := VK_RCONTROL
  else if (Name = 'LEFTALT') or (Name = 'LALT') then
    Result := VK_LMENU
  else if (Name = 'RIGHTALT') or (Name = 'RALT') then
    Result := VK_RMENU
  else if (Name = 'SEMICOLON') or (Name = 'OEM1') then
    Result := VK_OEM_1
  else if (Name = 'PLUS') or (Name = 'EQUALS') or (Name = 'OEMPLUS') then
    Result := VK_OEM_PLUS
  else if (Name = 'COMMA') or (Name = 'OEMCOMMA') then
    Result := VK_OEM_COMMA
  else if (Name = 'MINUS') or (Name = 'OEMMINUS') then
    Result := VK_OEM_MINUS
  else if (Name = 'PERIOD') or (Name = 'DOT') or (Name = 'OEMPERIOD') then
    Result := VK_OEM_PERIOD
  else if (Name = 'SLASH') or (Name = 'FORWARDSLASH') or (Name = 'OEM2') then
    Result := VK_OEM_2
  else if (Name = 'BACKQUOTE') or (Name = 'TILDE') or (Name = 'OEM3') then
    Result := VK_OEM_3
  else if (Name = 'LEFTBRACKET') or (Name = 'OEM4') then
    Result := VK_OEM_4
  else if (Name = 'BACKSLASH') or (Name = 'OEM5') then
    Result := VK_OEM_5
  else if (Name = 'RIGHTBRACKET') or (Name = 'OEM6') then
    Result := VK_OEM_6
  else if (Name = 'QUOTE') or (Name = 'APOSTROPHE') or (Name = 'OEM7') then
    Result := VK_OEM_7
  else
    raise Exception.CreateFmt('Unknown keyboard key name: %s', [AName]);
end;

function KeyCode(const AName: string): Integer;
begin
  Result := ResolveKeyCode(AName);
end;

function IsKeyPressed(const AKeyCode: Integer): Boolean;
begin
  Result := TKeyboard.IsKeyPressed(AKeyCode);
end;

function IsKeyPressed(const AKeyName: string): Boolean;
begin
  Result := TKeyboard.IsKeyPressed(AKeyName);
end;

class function TKeyboard.KeyCode(const AName: string): Integer;
begin
  Result := ResolveKeyCode(AName);
end;

class function TKeyboard.IsKeyPressed(const AKeyCode: Integer): Boolean;
begin
  Result := (AKeyCode >= 0) and (AKeyCode <= 255) and
    ((Word(GetAsyncKeyState(AKeyCode)) and $8000) <> 0);
end;

class function TKeyboard.IsKeyPressed(const AKeyName: string): Boolean;
begin
  Result := IsKeyPressed(KeyCode(AKeyName));
end;

end.
