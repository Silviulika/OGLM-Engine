unit Scripting.Serialization;

interface

uses
  System.Classes, System.SysUtils;

const
  SCRIPT_FILE_VERSION = 4;
  SCRIPT_ASSET_FILE_VERSION = 4;
  SCRIPT_FILE_MAGIC: array[0..7] of AnsiChar = ('O', 'M', 'E', 'S', 'C', 'R', '0', '1');
  SCRIPT_ASSET_FILE_MAGIC: array[0..7] of AnsiChar = ('O', 'M', 'E', 'S', 'C', 'A', '0', '1');

type
  TEngineScriptTargetKind = (
    stkGlobal,
    stkSceneObject,
    stkShader,
    stkMaterial,
    stkRenderTechnique
  );

  TEngineScriptExecutionResult = record
    Success: Boolean;
    Messages: string;

    class function Ok: TEngineScriptExecutionResult; static;
    class function Error(const AMessages: string): TEngineScriptExecutionResult; static;
  end;

  TEngineScriptAsset = class
  private
    FID: string;
    FName: string;
    FSource: string;
    FEntryPoint: string;
    FDescription: string;
    FAuthor: string;
    FCategory: string;
    FVersionText: string;
    FCreatedAt: TDateTime;
    FModifiedAt: TDateTime;
    FEnabled: Boolean;
    FTargetKind: TEngineScriptTargetKind;
    FTargetName: string;
    FRuntimeTarget: TObject;

  public
    class function NewID: string; static;
    constructor Create; virtual;

    procedure Assign(Source: TEngineScriptAsset);
    procedure Touch;
    procedure SaveToStream(Stream: TStream); overload;
    procedure SaveToStream(Stream: TStream; AVersion: Integer); overload;
    procedure LoadFromStream(Stream: TStream); overload;
    procedure LoadFromStream(Stream: TStream; AVersion: Integer); overload;

    property ID: string read FID write FID;
    property Name: string read FName write FName;
    property Source: string read FSource write FSource;
    property EntryPoint: string read FEntryPoint write FEntryPoint;
    property Description: string read FDescription write FDescription;
    property Author: string read FAuthor write FAuthor;
    property Category: string read FCategory write FCategory;
    property VersionText: string read FVersionText write FVersionText;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property ModifiedAt: TDateTime read FModifiedAt write FModifiedAt;
    property Enabled: Boolean read FEnabled write FEnabled;
    property TargetKind: TEngineScriptTargetKind read FTargetKind write FTargetKind;
    property TargetName: string read FTargetName write FTargetName;
    property RuntimeTarget: TObject read FRuntimeTarget write FRuntimeTarget;
  end;

function ScriptMagicMatches(const Magic: array of AnsiChar): Boolean;
function ScriptAssetMagicMatches(const Magic: array of AnsiChar): Boolean;

implementation

const
  SCRIPT_SOURCE_KEY: array[0..15] of Byte =
    ($4F, $47, $4C, $2D, $4D, $45, $2D, $53,
     $43, $52, $49, $50, $54, $2D, $30, $33);

procedure WriteScriptString(Stream: TStream; const Value: string);
var
  Len: Integer;
begin
  Len := Length(Value);
  Stream.WriteBuffer(Len, SizeOf(Len));
  if Len > 0 then
    Stream.WriteBuffer(Value[1], Len * SizeOf(Char));
end;

function ReadScriptString(Stream: TStream): string;
var
  Len: Integer;
begin
  Stream.ReadBuffer(Len, SizeOf(Len));
  if Len < 0 then
    raise Exception.Create('Invalid string length in script stream.');

  SetLength(Result, Len);
  if Len > 0 then
    Stream.ReadBuffer(Result[1], Len * SizeOf(Char));
end;

function ScriptBytesChecksum(const Data: TBytes): Cardinal;
var
  B: Byte;
  HashValue: UInt64;
begin
  HashValue := $811C9DC5;
  for B in Data do
    HashValue := ((HashValue xor B) * $01000193) and $FFFFFFFF;
  Result := Cardinal(HashValue);
end;

procedure CryptScriptBytes(var Data: TBytes);
var
  I: Integer;
begin
  for I := 0 to High(Data) do
    Data[I] := Data[I] xor SCRIPT_SOURCE_KEY[I mod Length(SCRIPT_SOURCE_KEY)] xor
      Byte((I * 31 + Length(Data)) and $FF);
end;

procedure WriteEncryptedScriptString(Stream: TStream; const Value: string);
var
  Data: TBytes;
  Len: Integer;
  Checksum: Cardinal;
begin
  Data := TEncoding.UTF8.GetBytes(Value);
  Checksum := ScriptBytesChecksum(Data);
  CryptScriptBytes(Data);

  Len := Length(Data);
  Stream.WriteBuffer(Len, SizeOf(Len));
  Stream.WriteBuffer(Checksum, SizeOf(Checksum));
  if Len > 0 then
    Stream.WriteBuffer(Data[0], Len);
end;

function ReadEncryptedScriptString(Stream: TStream): string;
var
  Data: TBytes;
  Len: Integer;
  StoredChecksum: Cardinal;
begin
  Stream.ReadBuffer(Len, SizeOf(Len));
  if (Len < 0) or (Len > 32 * 1024 * 1024) then
    raise Exception.Create('Invalid encrypted script string length.');

  Stream.ReadBuffer(StoredChecksum, SizeOf(StoredChecksum));
  SetLength(Data, Len);
  if Len > 0 then
  begin
    Stream.ReadBuffer(Data[0], Len);
    CryptScriptBytes(Data);
  end;

  if ScriptBytesChecksum(Data) <> StoredChecksum then
    raise Exception.Create('Script source integrity check failed.');

  Result := TEncoding.UTF8.GetString(Data, 0, Length(Data));
end;

function ScriptMagicMatches(const Magic: array of AnsiChar): Boolean;
var
  I: Integer;
begin
  Result := Length(Magic) = Length(SCRIPT_FILE_MAGIC);
  if not Result then
    Exit;

  for I := 0 to High(SCRIPT_FILE_MAGIC) do
    if Magic[I] <> SCRIPT_FILE_MAGIC[I] then
      Exit(False);
end;

function ScriptAssetMagicMatches(const Magic: array of AnsiChar): Boolean;
var
  I: Integer;
begin
  Result := Length(Magic) = Length(SCRIPT_ASSET_FILE_MAGIC);
  if not Result then
    Exit;

  for I := 0 to High(SCRIPT_ASSET_FILE_MAGIC) do
    if Magic[I] <> SCRIPT_ASSET_FILE_MAGIC[I] then
      Exit(False);
end;


{ TEngineScriptExecutionResult }

class function TEngineScriptExecutionResult.Ok: TEngineScriptExecutionResult;
begin
  Result.Success := True;
  Result.Messages := '';
end;

class function TEngineScriptExecutionResult.Error(
  const AMessages: string): TEngineScriptExecutionResult;
begin
  Result.Success := False;
  Result.Messages := AMessages;
end;

{ TEngineScriptAsset }

constructor TEngineScriptAsset.Create;
begin
  inherited Create;
  FID := NewID;
  FName := 'Script';
  FVersionText := '1.0';
  FCreatedAt := Now;
  FModifiedAt := FCreatedAt;
  FEnabled := True;
  FTargetKind := stkGlobal;
end;

class function TEngineScriptAsset.NewID: string;
var
  Guid: TGUID;
begin
  CreateGUID(Guid);
  Result := GUIDToString(Guid);
end;

procedure TEngineScriptAsset.Assign(Source: TEngineScriptAsset);
begin
  if Source = nil then
    Exit;

  FID := Source.FID;
  FName := Source.FName;
  FSource := Source.FSource;
  FEntryPoint := Source.FEntryPoint;
  FDescription := Source.FDescription;
  FAuthor := Source.FAuthor;
  FCategory := Source.FCategory;
  FVersionText := Source.FVersionText;
  FCreatedAt := Source.FCreatedAt;
  FModifiedAt := Source.FModifiedAt;
  FEnabled := Source.FEnabled;
  FTargetKind := Source.FTargetKind;
  FTargetName := Source.FTargetName;
  FRuntimeTarget := Source.FRuntimeTarget;
end;

procedure TEngineScriptAsset.SaveToStream(Stream: TStream);
begin
  SaveToStream(Stream, SCRIPT_FILE_VERSION);
end;

procedure TEngineScriptAsset.Touch;
begin
  FModifiedAt := Now;
end;

procedure TEngineScriptAsset.SaveToStream(Stream: TStream; AVersion: Integer);
var
  KindValue: Integer;
begin
  WriteScriptString(Stream, FID);
  WriteScriptString(Stream, FName);
  if AVersion = 3 then
    WriteEncryptedScriptString(Stream, FSource)
  else
    WriteScriptString(Stream, FSource);
  WriteScriptString(Stream, FEntryPoint);
  Stream.WriteBuffer(FEnabled, SizeOf(FEnabled));
  KindValue := Ord(FTargetKind);
  Stream.WriteBuffer(KindValue, SizeOf(KindValue));
  WriteScriptString(Stream, FTargetName);

  if AVersion >= 2 then
  begin
    WriteScriptString(Stream, FDescription);
    WriteScriptString(Stream, FAuthor);
    WriteScriptString(Stream, FCategory);
    WriteScriptString(Stream, FVersionText);
    Stream.WriteBuffer(FCreatedAt, SizeOf(FCreatedAt));
    Stream.WriteBuffer(FModifiedAt, SizeOf(FModifiedAt));
  end;
end;

procedure TEngineScriptAsset.LoadFromStream(Stream: TStream);
begin
  LoadFromStream(Stream, SCRIPT_FILE_VERSION);
end;

procedure TEngineScriptAsset.LoadFromStream(Stream: TStream; AVersion: Integer);
var
  KindValue: Integer;
begin
  FID := ReadScriptString(Stream);
  FName := ReadScriptString(Stream);
  if AVersion = 3 then
    FSource := ReadEncryptedScriptString(Stream)
  else
    FSource := ReadScriptString(Stream);
  FEntryPoint := ReadScriptString(Stream);
  Stream.ReadBuffer(FEnabled, SizeOf(FEnabled));
  Stream.ReadBuffer(KindValue, SizeOf(KindValue));
  if (KindValue < Ord(Low(TEngineScriptTargetKind))) or
     (KindValue > Ord(High(TEngineScriptTargetKind))) then
    raise Exception.CreateFmt('Invalid script target kind: %d.', [KindValue]);
  FTargetKind := TEngineScriptTargetKind(KindValue);
  FTargetName := ReadScriptString(Stream);
  FRuntimeTarget := nil;

  FDescription := '';
  FAuthor := '';
  FCategory := '';
  FVersionText := '1.0';
  FCreatedAt := Now;
  FModifiedAt := FCreatedAt;

  if AVersion >= 2 then
  begin
    FDescription := ReadScriptString(Stream);
    FAuthor := ReadScriptString(Stream);
    FCategory := ReadScriptString(Stream);
    FVersionText := ReadScriptString(Stream);
    Stream.ReadBuffer(FCreatedAt, SizeOf(FCreatedAt));
    Stream.ReadBuffer(FModifiedAt, SizeOf(FModifiedAt));
  end;

  if FID = '' then
    FID := NewID;
  if FName = '' then
    FName := 'Script';
  if FVersionText = '' then
    FVersionText := '1.0';
end;


end.