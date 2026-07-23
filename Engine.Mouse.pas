unit Engine.Mouse;

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Math,
  Neslib.FastMath,
  Engine.Types,
  Managers.Scene,
  Renderer.Mesh,
  Renderer.Renderer;

type
  TMouse = class
  private
    class function RendererWindowHandle(ARenderer: TRenderer): HWND; static;
    class function IntersectLocalAABB(const ARayOrigin, ARayDirection: TVector3;
      const ABounds: TAABB; out ATMin, ATMax: Single): Boolean; static;
  public
    class function ButtonCode(const AName: string): Integer; static;
    class function IsButtonPressed(const AButtonCode: Integer): Boolean; overload; static;
    class function IsButtonPressed(const AButtonName: string): Boolean; overload; static;

    class function Position(ARenderer: TRenderer): TVector2; static;
    class function IsInsideViewport(ARenderer: TRenderer): Boolean; static;

    class function TryScreenToWorldRay(ARenderer: TRenderer; const AScreenX,
      AScreenY: Single; out ARayOrigin, ARayDirection: TVector3): Boolean; static;
    class function TryCurrentWorldRay(ARenderer: TRenderer; out ARayOrigin,
      ARayDirection: TVector3): Boolean; static;

    class function TryRayPlaneHit(const ARayOrigin, ARayDirection,
      APlanePoint, APlaneNormal: TVector3; out AHitPoint: TVector3;
      out ADistance: Single): Boolean; static;
    class function TryScreenPlaneHit(ARenderer: TRenderer; const AScreenX,
      AScreenY: Single; const APlanePoint, APlaneNormal: TVector3;
      out AHitPoint: TVector3; out ADistance: Single): Boolean; static;
    class function TryCurrentPlaneHit(ARenderer: TRenderer; const APlanePoint,
      APlaneNormal: TVector3; out AHitPoint: TVector3;
      out ADistance: Single): Boolean; static;

    class function HeightFieldLocalHeight(AHeightField: THeightFieldMesh;
      const ALocalX, ALocalZ: Single): Single; static;
    class function HeightFieldWorldPoint(AHeightField: THeightFieldMesh;
      const AWorldPoint: TVector3): TVector3; static;

    class function TryRayHeightFieldHit(AHeightField: THeightFieldMesh;
      const ARayOrigin, ARayDirection: TVector3; out AWorldPoint,
      ALocalPoint: TVector3; out ADistance: Single): Boolean; static;
    class function TryScreenHeightFieldHit(ARenderer: TRenderer;
      AHeightField: THeightFieldMesh; const AScreenX, AScreenY: Single;
      out AWorldPoint, ALocalPoint: TVector3; out ADistance: Single): Boolean; static;
    class function TryCurrentHeightFieldHit(ARenderer: TRenderer;
      AHeightField: THeightFieldMesh; out AWorldPoint, ALocalPoint: TVector3;
      out ADistance: Single): Boolean; static;
  end;

implementation

uses
  Utility.Functions;

const
  MOUSE_RAY_EPSILON = 1e-5;
  HEIGHTFIELD_RAY_STEPS = 160;
  HEIGHTFIELD_RAY_REFINE_STEPS = 18;

function NormalizeMouseName(const AName: string): string;
begin
  Result := UpperCase(Trim(AName));
  Result := StringReplace(Result, ' ', '', [rfReplaceAll]);
  Result := StringReplace(Result, '_', '', [rfReplaceAll]);
  Result := StringReplace(Result, '-', '', [rfReplaceAll]);
end;

class function TMouse.RendererWindowHandle(ARenderer: TRenderer): HWND;
begin
  Result := 0;
  if (ARenderer <> nil) and (ARenderer.RenderContext <> nil) then
    Result := ARenderer.RenderContext.WindowHandle;
end;

class function TMouse.ButtonCode(const AName: string): Integer;
var
  Name: string;
begin
  Name := NormalizeMouseName(AName);
  if (Name = 'LEFT') or (Name = 'LBUTTON') or (Name = 'MOUSELEFT') then
    Result := VK_LBUTTON
  else if (Name = 'RIGHT') or (Name = 'RBUTTON') or (Name = 'MOUSERIGHT') then
    Result := VK_RBUTTON
  else if (Name = 'MIDDLE') or (Name = 'MBUTTON') or (Name = 'MOUSEMIDDLE') or
          (Name = 'WHEEL') then
    Result := VK_MBUTTON
  else if (Name = 'X1') or (Name = 'XBUTTON1') or (Name = 'MOUSEX1') then
    Result := VK_XBUTTON1
  else if (Name = 'X2') or (Name = 'XBUTTON2') or (Name = 'MOUSEX2') then
    Result := VK_XBUTTON2
  else
    raise Exception.CreateFmt('Unknown mouse button name: %s', [AName]);
end;

class function TMouse.IsButtonPressed(const AButtonCode: Integer): Boolean;
begin
  Result := (AButtonCode >= 0) and (AButtonCode <= 255) and
    ((Word(GetAsyncKeyState(AButtonCode)) and $8000) <> 0);
end;

class function TMouse.IsButtonPressed(const AButtonName: string): Boolean;
begin
  Result := IsButtonPressed(ButtonCode(AButtonName));
end;

class function TMouse.Position(ARenderer: TRenderer): TVector2;
var
  P: TPoint;
  WindowHandle: HWND;
begin
  Result := Vector2(0.0, 0.0);
  WindowHandle := RendererWindowHandle(ARenderer);
  if WindowHandle = 0 then
    Exit;

  if not GetCursorPos(P) then
    Exit;

  if not ScreenToClient(WindowHandle, P) then
    Exit;

  Result := Vector2(P.X, P.Y);
end;

class function TMouse.IsInsideViewport(ARenderer: TRenderer): Boolean;
var
  P: TVector2;
begin
  Result := False;
  if ARenderer = nil then
    Exit;

  P := Position(ARenderer);
  Result := (P.X >= 0.0) and (P.Y >= 0.0) and
    (P.X < ARenderer.Width) and (P.Y < ARenderer.Height);
end;

class function TMouse.TryScreenToWorldRay(ARenderer: TRenderer;
  const AScreenX, AScreenY: Single; out ARayOrigin,
  ARayDirection: TVector3): Boolean;
begin
  ARayOrigin := Vector3(0.0, 0.0, 0.0);
  ARayDirection := Vector3(0.0, 0.0, -1.0);
  Result := False;

  if (ARenderer = nil) or (ARenderer.Width <= 0) or (ARenderer.Height <= 0) then
    Exit;
  if (ARenderer.ActiveCamera = nil) or (ARenderer.ActiveCamera.Camera = nil) then
    Exit;

  ScreenToWorldRay(Round(AScreenX), Round(AScreenY), ARenderer.Width,
    ARenderer.Height, ARenderer.ActiveCamera.Camera.ViewMatrix,
    ARenderer.ProjectionMatrix, ARayOrigin, ARayDirection);

  Result := ARayDirection.LengthSquared > MOUSE_RAY_EPSILON;
end;

class function TMouse.TryCurrentWorldRay(ARenderer: TRenderer; out ARayOrigin,
  ARayDirection: TVector3): Boolean;
var
  P: TVector2;
begin
  P := Position(ARenderer);
  Result := TryScreenToWorldRay(ARenderer, P.X, P.Y, ARayOrigin, ARayDirection);
end;

class function TMouse.TryRayPlaneHit(const ARayOrigin, ARayDirection,
  APlanePoint, APlaneNormal: TVector3; out AHitPoint: TVector3;
  out ADistance: Single): Boolean;
var
  Normal: TVector3;
  NormalLength, Denom, T: Single;
begin
  Result := False;
  AHitPoint := Vector3(0.0, 0.0, 0.0);
  ADistance := 0.0;

  NormalLength := APlaneNormal.Length;
  if NormalLength <= MOUSE_RAY_EPSILON then
    Exit;

  Normal := APlaneNormal / NormalLength;
  Denom := Normal.Dot(ARayDirection);
  if Abs(Denom) < MOUSE_RAY_EPSILON then
    Exit;

  T := Normal.Dot(APlanePoint - ARayOrigin) / Denom;
  if T < 0.0 then
    Exit;

  AHitPoint := ARayOrigin + ARayDirection * T;
  ADistance := T;
  Result := True;
end;

class function TMouse.TryScreenPlaneHit(ARenderer: TRenderer; const AScreenX,
  AScreenY: Single; const APlanePoint, APlaneNormal: TVector3;
  out AHitPoint: TVector3; out ADistance: Single): Boolean;
var
  RayOrigin, RayDirection: TVector3;
begin
  Result := TryScreenToWorldRay(ARenderer, AScreenX, AScreenY, RayOrigin,
    RayDirection) and TryRayPlaneHit(RayOrigin, RayDirection, APlanePoint,
    APlaneNormal, AHitPoint, ADistance);
end;

class function TMouse.TryCurrentPlaneHit(ARenderer: TRenderer;
  const APlanePoint, APlaneNormal: TVector3; out AHitPoint: TVector3;
  out ADistance: Single): Boolean;
var
  P: TVector2;
begin
  P := Position(ARenderer);
  Result := TryScreenPlaneHit(ARenderer, P.X, P.Y, APlanePoint, APlaneNormal,
    AHitPoint, ADistance);
end;

class function TMouse.HeightFieldLocalHeight(AHeightField: THeightFieldMesh;
  const ALocalX, ALocalZ: Single): Single;
begin
  Result := 0.0;
  if AHeightField <> nil then
    Result := AHeightField.InterpolatedHeight(ALocalX, ALocalZ);
end;

class function TMouse.HeightFieldWorldPoint(AHeightField: THeightFieldMesh;
  const AWorldPoint: TVector3): TVector3;
var
  LocalPoint: TVector3;
begin
  Result := AWorldPoint;
  if AHeightField = nil then
    Exit;

  LocalPoint := Vector3(AHeightField.ModelMatrix.Inverse * Vector4(AWorldPoint, 1.0));
  LocalPoint.Y := AHeightField.InterpolatedHeight(LocalPoint.X, LocalPoint.Z);
  Result := Vector3(AHeightField.ModelMatrix * Vector4(LocalPoint, 1.0));
end;

class function TMouse.IntersectLocalAABB(const ARayOrigin,
  ARayDirection: TVector3; const ABounds: TAABB; out ATMin,
  ATMax: Single): Boolean;
var
  BoundsMin, BoundsMax: TVector3;

  procedure CheckAxis(const AOrigin, ADirection, AMin, AMax: Single;
    var AEnter, AExit: Single; var AValid: Boolean);
  var
    T1, T2, Temp: Single;
  begin
    if not AValid then
      Exit;

    if Abs(ADirection) < MOUSE_RAY_EPSILON then
    begin
      if (AOrigin < AMin) or (AOrigin > AMax) then
        AValid := False;
      Exit;
    end;

    T1 := (AMin - AOrigin) / ADirection;
    T2 := (AMax - AOrigin) / ADirection;
    if T1 > T2 then
    begin
      Temp := T1;
      T1 := T2;
      T2 := Temp;
    end;

    if T1 > AEnter then
      AEnter := T1;
    if T2 < AExit then
      AExit := T2;
    if AEnter > AExit then
      AValid := False;
  end;

begin
  Result := ABounds.IsValid;
  if not Result then
    Exit;

  BoundsMin := ABounds.Min - Vector3(0.01, 0.01, 0.01);
  BoundsMax := ABounds.Max + Vector3(0.01, 0.01, 0.01);

  ATMin := -MaxSingle;
  ATMax := MaxSingle;
  CheckAxis(ARayOrigin.X, ARayDirection.X, BoundsMin.X, BoundsMax.X, ATMin, ATMax, Result);
  CheckAxis(ARayOrigin.Y, ARayDirection.Y, BoundsMin.Y, BoundsMax.Y, ATMin, ATMax, Result);
  CheckAxis(ARayOrigin.Z, ARayDirection.Z, BoundsMin.Z, BoundsMax.Z, ATMin, ATMax, Result);
  Result := Result and (ATMax >= 0.0);
end;

class function TMouse.TryRayHeightFieldHit(AHeightField: THeightFieldMesh;
  const ARayOrigin, ARayDirection: TVector3; out AWorldPoint,
  ALocalPoint: TVector3; out ADistance: Single): Boolean;
var
  InverseModel: TMatrix4;
  LocalRayOrigin, LocalRayDirection: TVector3;
  LocalDirectionLength: Single;
  TStart, TEnd, TPrev, TCurr, TMid: Single;
  FPrev, FCurr, FMid: Single;
  I, J: Integer;
  LocalBounds: TAABB;

  function HeightDelta(const AT: Single): Single;
  var
    P: TVector3;
  begin
    P := LocalRayOrigin + LocalRayDirection * AT;
    Result := P.Y - AHeightField.InterpolatedHeight(P.X, P.Z);
  end;

  procedure SetHitAt(const AT: Single);
  begin
    ALocalPoint := LocalRayOrigin + LocalRayDirection * AT;
    ALocalPoint.Y := AHeightField.InterpolatedHeight(ALocalPoint.X, ALocalPoint.Z);
    AWorldPoint := Vector3(AHeightField.ModelMatrix * Vector4(ALocalPoint, 1.0));
    ADistance := (AWorldPoint - ARayOrigin).Length;
  end;

begin
  Result := False;
  AWorldPoint := Vector3(0.0, 0.0, 0.0);
  ALocalPoint := Vector3(0.0, 0.0, 0.0);
  ADistance := 0.0;

  if AHeightField = nil then
    Exit;

  InverseModel := AHeightField.ModelMatrix.Inverse;
  LocalRayOrigin := Vector3(InverseModel * Vector4(ARayOrigin, 1.0));
  LocalRayDirection := Vector3(InverseModel * Vector4(ARayDirection, 0.0));
  LocalDirectionLength := LocalRayDirection.Length;
  if LocalDirectionLength <= MOUSE_RAY_EPSILON then
    Exit;
  LocalRayDirection := LocalRayDirection / LocalDirectionLength;

  LocalBounds := AHeightField.GetBoundingBox;
  if not IntersectLocalAABB(LocalRayOrigin, LocalRayDirection, LocalBounds,
    TStart, TEnd) then
    Exit;

  TStart := Max(0.0, TStart);
  if TEnd < TStart then
    Exit;

  TPrev := TStart;
  FPrev := HeightDelta(TPrev);
  if Abs(FPrev) <= 0.01 then
  begin
    SetHitAt(TPrev);
    Exit(True);
  end;

  for I := 1 to HEIGHTFIELD_RAY_STEPS do
  begin
    TCurr := TStart + (TEnd - TStart) * (I / HEIGHTFIELD_RAY_STEPS);
    FCurr := HeightDelta(TCurr);

    if Abs(FCurr) <= 0.01 then
    begin
      SetHitAt(TCurr);
      Exit(True);
    end;

    if ((FPrev < 0.0) and (FCurr > 0.0)) or
       ((FPrev > 0.0) and (FCurr < 0.0)) then
    begin
      for J := 0 to HEIGHTFIELD_RAY_REFINE_STEPS - 1 do
      begin
        TMid := (TPrev + TCurr) * 0.5;
        FMid := HeightDelta(TMid);

        if Abs(FMid) <= 0.001 then
        begin
          TPrev := TMid;
          TCurr := TMid;
          Break;
        end;

        if ((FPrev < 0.0) and (FMid < 0.0)) or
           ((FPrev > 0.0) and (FMid > 0.0)) then
        begin
          TPrev := TMid;
          FPrev := FMid;
        end
        else
          TCurr := TMid;
      end;

      SetHitAt((TPrev + TCurr) * 0.5);
      Exit(True);
    end;

    TPrev := TCurr;
    FPrev := FCurr;
  end;
end;

class function TMouse.TryScreenHeightFieldHit(ARenderer: TRenderer;
  AHeightField: THeightFieldMesh; const AScreenX, AScreenY: Single;
  out AWorldPoint, ALocalPoint: TVector3; out ADistance: Single): Boolean;
var
  RayOrigin, RayDirection: TVector3;
begin
  Result := TryScreenToWorldRay(ARenderer, AScreenX, AScreenY, RayOrigin,
    RayDirection) and TryRayHeightFieldHit(AHeightField, RayOrigin,
    RayDirection, AWorldPoint, ALocalPoint, ADistance);
end;

class function TMouse.TryCurrentHeightFieldHit(ARenderer: TRenderer;
  AHeightField: THeightFieldMesh; out AWorldPoint, ALocalPoint: TVector3;
  out ADistance: Single): Boolean;
var
  P: TVector2;
begin
  P := Position(ARenderer);
  Result := TryScreenHeightFieldHit(ARenderer, AHeightField, P.X, P.Y,
    AWorldPoint, ALocalPoint, ADistance);
end;

end.
