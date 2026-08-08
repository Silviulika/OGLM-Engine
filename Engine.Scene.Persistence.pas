unit Engine.Scene.Persistence;

interface

uses
  System.Classes;

function EngineMagicMatches(const A, B: array of AnsiChar): Boolean;
function StreamStartsWithMagic(AStream: TStream;
  const AExpectedMagic: array of AnsiChar): Boolean;
function TryBeginSceneChunk(AStream: TStream;
  const AExpectedMagic: array of AnsiChar; AExpectedVersion: Integer;
  const AChunkName: string; out APayloadEnd: Int64): Boolean;
function TrySkipSceneChunk(AStream: TStream;
  const AExpectedMagic: array of AnsiChar; AExpectedVersion: Integer;
  const AChunkName: string): Boolean;

procedure AppendSceneChecksum(AStream: TStream);
procedure ValidateSceneChecksum(AStream: TStream; out AContentEnd: Int64);
procedure FlushSceneFile(AStream: TFileStream);
procedure AtomicReplaceSceneFile(const ATemporaryFileName,
  ADestinationFileName, ABackupFileName: string);

implementation

uses
  Winapi.Windows,
  System.SysUtils;

const
  SCENE_CHECKSUM_VERSION = 1;
  SCENE_CHECKSUM_MAGIC: array[0..7] of AnsiChar =
    ('O', 'M', 'E', 'C', 'R', 'C', '0', '1');
  CRC32_POLYNOMIAL = Cardinal($EDB88320);

type
  TSceneChecksumTrailer = packed record
    Magic: array[0..7] of AnsiChar;
    Version: Cardinal;
    ContentSize: Int64;
    Checksum: Cardinal;
  end;

var
  CRC32Table: array[Byte] of Cardinal;

procedure InitializeCRC32Table;
var
  I, BitIndex: Integer;
  Value: Cardinal;
begin
  for I := 0 to 255 do
  begin
    Value := Cardinal(I);
    for BitIndex := 0 to 7 do
      if (Value and 1) <> 0 then
        Value := (Value shr 1) xor CRC32_POLYNOMIAL
      else
        Value := Value shr 1;
    CRC32Table[Byte(I)] := Value;
  end;
end;

function EngineMagicMatches(const A, B: array of AnsiChar): Boolean;
var
  I: Integer;
begin
  Result := Length(A) = Length(B);
  if not Result then
    Exit;
  for I := Low(A) to High(A) do
    if A[I] <> B[I - Low(A) + Low(B)] then
      Exit(False);
end;

function StreamStartsWithMagic(AStream: TStream;
  const AExpectedMagic: array of AnsiChar): Boolean;
var
  StartPosition: Int64;
  Magic: array[0..7] of AnsiChar;
begin
  Result := False;
  if (AStream = nil) or
     ((AStream.Size - AStream.Position) < SizeOf(Magic)) then
    Exit;

  StartPosition := AStream.Position;
  try
    AStream.ReadBuffer(Magic[0], SizeOf(Magic));
    Result := EngineMagicMatches(Magic, AExpectedMagic);
  finally
    AStream.Position := StartPosition;
  end;
end;

function TryBeginSceneChunk(AStream: TStream;
  const AExpectedMagic: array of AnsiChar; AExpectedVersion: Integer;
  const AChunkName: string; out APayloadEnd: Int64): Boolean;
var
  StartPosition: Int64;
  PayloadSize: Int64;
  Magic: array[0..7] of AnsiChar;
  Version: Integer;
begin
  Result := False;
  APayloadEnd := 0;
  if AStream = nil then
    Exit;

  StartPosition := AStream.Position;
  if (AStream.Size - AStream.Position) < SizeOf(Magic) then
    Exit;

  AStream.ReadBuffer(Magic[0], SizeOf(Magic));
  if not EngineMagicMatches(Magic, AExpectedMagic) then
  begin
    AStream.Position := StartPosition;
    Exit;
  end;

  Result := True;
  if (AStream.Size - AStream.Position) <
     (SizeOf(Version) + SizeOf(PayloadSize)) then
    raise Exception.CreateFmt('Invalid %s header.', [AChunkName]);

  AStream.ReadBuffer(Version, SizeOf(Version));
  AStream.ReadBuffer(PayloadSize, SizeOf(PayloadSize));
  if (Version < 1) or (Version > AExpectedVersion) then
    raise Exception.CreateFmt('Unsupported %s version: %d.',
      [AChunkName, Version]);
  if (PayloadSize < 0) or
     (PayloadSize > (AStream.Size - AStream.Position)) then
    raise Exception.CreateFmt('Invalid %s payload size.', [AChunkName]);

  APayloadEnd := AStream.Position + PayloadSize;
end;

function TrySkipSceneChunk(AStream: TStream;
  const AExpectedMagic: array of AnsiChar; AExpectedVersion: Integer;
  const AChunkName: string): Boolean;
var
  PayloadEnd: Int64;
begin
  Result := TryBeginSceneChunk(AStream, AExpectedMagic, AExpectedVersion,
    AChunkName, PayloadEnd);
  if Result then
    AStream.Position := PayloadEnd;
end;

function CalculateCRC32(AStream: TStream; AByteCount: Int64): Cardinal;
const
  BUFFER_SIZE = 64 * 1024;
var
  Buffer: TBytes;
  SavedPosition: Int64;
  Remaining: Int64;
  ReadCount: Integer;
  I: Integer;
begin
  if AStream = nil then
    raise EArgumentNilException.Create('AStream');
  if (AByteCount < 0) or (AByteCount > AStream.Size) then
    raise EArgumentOutOfRangeException.Create('AByteCount');

  SavedPosition := AStream.Position;
  SetLength(Buffer, BUFFER_SIZE);
  Remaining := AByteCount;
  Result := Cardinal($FFFFFFFF);
  try
    AStream.Position := 0;
    while Remaining > 0 do
    begin
      ReadCount := Length(Buffer);
      if Remaining < ReadCount then
        ReadCount := Integer(Remaining);
      AStream.ReadBuffer(Buffer[0], ReadCount);

      for I := 0 to ReadCount - 1 do
        Result := (Result shr 8) xor
          CRC32Table[Byte((Result xor Buffer[I]) and $FF)];
      Dec(Remaining, ReadCount);
    end;
    Result := not Result;
  finally
    AStream.Position := SavedPosition;
  end;
end;

procedure AppendSceneChecksum(AStream: TStream);
var
  Trailer: TSceneChecksumTrailer;
  I: Integer;
begin
  if AStream = nil then
    raise EArgumentNilException.Create('AStream');

  FillChar(Trailer, SizeOf(Trailer), 0);
  for I := Low(SCENE_CHECKSUM_MAGIC) to High(SCENE_CHECKSUM_MAGIC) do
    Trailer.Magic[I] := SCENE_CHECKSUM_MAGIC[I];
  Trailer.Version := SCENE_CHECKSUM_VERSION;
  Trailer.ContentSize := AStream.Size;
  Trailer.Checksum := CalculateCRC32(AStream, Trailer.ContentSize);

  AStream.Position := Trailer.ContentSize;
  AStream.WriteBuffer(Trailer, SizeOf(Trailer));
end;

procedure ValidateSceneChecksum(AStream: TStream; out AContentEnd: Int64);
var
  Trailer: TSceneChecksumTrailer;
  TrailerPosition: Int64;
  ActualChecksum: Cardinal;
begin
  if AStream = nil then
    raise EArgumentNilException.Create('AStream');

  AContentEnd := AStream.Size;
  AStream.Position := 0;
  if AStream.Size < SizeOf(Trailer) then
    Exit; // Legacy scene without a checksum trailer.

  TrailerPosition := AStream.Size - SizeOf(Trailer);
  AStream.Position := TrailerPosition;
  AStream.ReadBuffer(Trailer, SizeOf(Trailer));
  if not EngineMagicMatches(Trailer.Magic, SCENE_CHECKSUM_MAGIC) then
  begin
    AStream.Position := 0;
    Exit; // Legacy scene without a checksum trailer.
  end;

  if Trailer.Version <> SCENE_CHECKSUM_VERSION then
    raise Exception.CreateFmt('Unsupported scene checksum version: %d.',
      [Trailer.Version]);
  if Trailer.ContentSize <> TrailerPosition then
    raise Exception.Create('Invalid scene checksum content length.');

  ActualChecksum := CalculateCRC32(AStream, Trailer.ContentSize);
  if ActualChecksum <> Trailer.Checksum then
    raise Exception.Create('Scene checksum validation failed.');

  AContentEnd := Trailer.ContentSize;
  AStream.Position := 0;
end;

procedure FlushSceneFile(AStream: TFileStream);
begin
  if AStream = nil then
    raise EArgumentNilException.Create('AStream');
  if not FlushFileBuffers(AStream.Handle) then
    RaiseLastOSError;
end;

procedure AtomicReplaceSceneFile(const ATemporaryFileName,
  ADestinationFileName, ABackupFileName: string);
var
  ErrorCode: Cardinal;
begin
  if not FileExists(ATemporaryFileName) then
    raise Exception.Create('Temporary scene file does not exist: ' +
      ATemporaryFileName);

  if FileExists(ADestinationFileName) then
  begin
    if (ABackupFileName <> '') and FileExists(ABackupFileName) and
       (not System.SysUtils.DeleteFile(ABackupFileName)) then
      RaiseLastOSError;

    if not Winapi.Windows.ReplaceFile(PChar(ADestinationFileName),
      PChar(ATemporaryFileName), PChar(ABackupFileName),
      REPLACEFILE_WRITE_THROUGH, nil, nil) then
    begin
      ErrorCode := GetLastError;
      if (not FileExists(ADestinationFileName)) and
         (ABackupFileName <> '') and FileExists(ABackupFileName) then
        MoveFileEx(PChar(ABackupFileName), PChar(ADestinationFileName),
          MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH);
      RaiseLastOSError(ErrorCode);
    end;
  end
  else if not MoveFileEx(PChar(ATemporaryFileName),
    PChar(ADestinationFileName), MOVEFILE_REPLACE_EXISTING or
    MOVEFILE_WRITE_THROUGH) then
    RaiseLastOSError;
end;

initialization
  InitializeCRC32Table;

end.
