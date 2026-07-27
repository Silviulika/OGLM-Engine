unit Engine.Gui.Scripting;

interface

uses
  System.Classes,
  System.SysUtils,
  System.IOUtils,
  System.Math,
  Vcl.StdCtrls,
  dwsComp,
  dwsExprs,
  dwsInfo,
  dwsSymbols,
  Neslib.FastMath,
  Engine.Paths,
  Engine.Gui,
  Engine.Gui.Controls,
  Engine.Gui.Manager;

type
  TdwsGuiUnit = class(TdwsUnit)
  private
    FManager: TGuiManager;
    FCurrentScriptName: string;
    FEventControl: TGuiControl;
    FEventName: string;
    FEventHandlerName: string;
    FEventData: TGuiEventData;

    procedure RegisterGuiFunction(const AName, AResultType: string;
      const AParamNames, AParamTypes: array of string;
      const AOnEval: TFuncEvalEvent; const AOverloaded: Boolean = False);
    procedure RegisterGuiClasses;
    procedure RequireManager;
    function RequireControl(ExtObject: TObject): TGuiControl;
    function ParamAsControl(Info: TProgramInfo; AIndex: Integer): TGuiControl;
    procedure SetResultControl(Info: TProgramInfo; AControl: TGuiControl);
    function InfoAsVector4(const AInfo: IInfo): TVector4;
    procedure SetResultVector4(Info: TProgramInfo; const AValue: TVector4);
    function ResolveGuiFileName(const AFileName: string): string;

    procedure DoControlCleanup(ExternalObject: TObject);
    procedure DoControlGetHandle(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlGetName(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlSetName(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlGetKind(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlGetParent(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlSetParent(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlGetChildCount(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlChild(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlDelete(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlGetLeft(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlSetLeft(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlGetTop(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlSetTop(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlGetWidth(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlSetWidth(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlGetHeight(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlSetHeight(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlGetVisible(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlSetVisible(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlGetScale(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlSetScale(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlGetTint(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlSetTint(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlGetLayoutName(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlSetLayoutName(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlSetBounds(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlShow(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlHide(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlBringToFront(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlSendToBack(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlEventHandler(Info: TProgramInfo; ExtObject: TObject);
    procedure DoControlSetEventHandler(Info: TProgramInfo; ExtObject: TObject);

    procedure DoTextGetCaption(Info: TProgramInfo; ExtObject: TObject);
    procedure DoTextSetCaption(Info: TProgramInfo; ExtObject: TObject);

    procedure DoButtonGetPressed(Info: TProgramInfo; ExtObject: TObject);
    procedure DoButtonSetPressed(Info: TProgramInfo; ExtObject: TObject);
    procedure DoButtonGetAllowUp(Info: TProgramInfo; ExtObject: TObject);
    procedure DoButtonSetAllowUp(Info: TProgramInfo; ExtObject: TObject);
    procedure DoButtonGetGroup(Info: TProgramInfo; ExtObject: TObject);
    procedure DoButtonSetGroup(Info: TProgramInfo; ExtObject: TObject);
    procedure DoButtonGetPressedLayoutName(Info: TProgramInfo; ExtObject: TObject);
    procedure DoButtonSetPressedLayoutName(Info: TProgramInfo; ExtObject: TObject);

    procedure DoCheckBoxGetChecked(Info: TProgramInfo; ExtObject: TObject);
    procedure DoCheckBoxSetChecked(Info: TProgramInfo; ExtObject: TObject);
    procedure DoCheckBoxGetGroup(Info: TProgramInfo; ExtObject: TObject);
    procedure DoCheckBoxSetGroup(Info: TProgramInfo; ExtObject: TObject);
    procedure DoCheckBoxGetCheckedLayoutName(Info: TProgramInfo; ExtObject: TObject);
    procedure DoCheckBoxSetCheckedLayoutName(Info: TProgramInfo; ExtObject: TObject);

    procedure DoEditGetReadOnly(Info: TProgramInfo; ExtObject: TObject);
    procedure DoEditSetReadOnly(Info: TProgramInfo; ExtObject: TObject);
    procedure DoEditGetSelStart(Info: TProgramInfo; ExtObject: TObject);
    procedure DoEditSetSelStart(Info: TProgramInfo; ExtObject: TObject);

    procedure DoLabelGetAlignment(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLabelSetAlignment(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLabelGetTextLayout(Info: TProgramInfo; ExtObject: TObject);
    procedure DoLabelSetTextLayout(Info: TProgramInfo; ExtObject: TObject);

    procedure DoWindowClose(Info: TProgramInfo; ExtObject: TObject);
    procedure DoWindowGetTitleOffset(Info: TProgramInfo; ExtObject: TObject);
    procedure DoWindowSetTitleOffset(Info: TProgramInfo; ExtObject: TObject);

    procedure DoScrollbarGetMin(Info: TProgramInfo; ExtObject: TObject);
    procedure DoScrollbarSetMin(Info: TProgramInfo; ExtObject: TObject);
    procedure DoScrollbarGetMax(Info: TProgramInfo; ExtObject: TObject);
    procedure DoScrollbarSetMax(Info: TProgramInfo; ExtObject: TObject);
    procedure DoScrollbarGetPosition(Info: TProgramInfo; ExtObject: TObject);
    procedure DoScrollbarSetPosition(Info: TProgramInfo; ExtObject: TObject);
    procedure DoScrollbarGetPageSize(Info: TProgramInfo; ExtObject: TObject);
    procedure DoScrollbarSetPageSize(Info: TProgramInfo; ExtObject: TObject);
    procedure DoScrollbarGetStep(Info: TProgramInfo; ExtObject: TObject);
    procedure DoScrollbarSetStep(Info: TProgramInfo; ExtObject: TObject);
    procedure DoScrollbarGetHorizontal(Info: TProgramInfo; ExtObject: TObject);
    procedure DoScrollbarSetHorizontal(Info: TProgramInfo; ExtObject: TObject);
    procedure DoScrollbarGetLocked(Info: TProgramInfo; ExtObject: TObject);
    procedure DoScrollbarSetLocked(Info: TProgramInfo; ExtObject: TObject);
    procedure DoScrollbarStepUp(Info: TProgramInfo; ExtObject: TObject);
    procedure DoScrollbarStepDown(Info: TProgramInfo; ExtObject: TObject);
    procedure DoScrollbarPageUp(Info: TProgramInfo; ExtObject: TObject);
    procedure DoScrollbarPageDown(Info: TProgramInfo; ExtObject: TObject);

    procedure DoPopupGetItemsText(Info: TProgramInfo; ExtObject: TObject);
    procedure DoPopupSetItemsText(Info: TProgramInfo; ExtObject: TObject);
    procedure DoPopupGetSelectedIndex(Info: TProgramInfo; ExtObject: TObject);
    procedure DoPopupSetSelectedIndex(Info: TProgramInfo; ExtObject: TObject);
    procedure DoPopupAddItem(Info: TProgramInfo; ExtObject: TObject);
    procedure DoPopupClear(Info: TProgramInfo; ExtObject: TObject);
    procedure DoPopupPopup(Info: TProgramInfo; ExtObject: TObject);

    procedure DoGridGetColumnsText(Info: TProgramInfo; ExtObject: TObject);
    procedure DoGridSetColumnsText(Info: TProgramInfo; ExtObject: TObject);
    procedure DoGridGetRowCount(Info: TProgramInfo; ExtObject: TObject);
    procedure DoGridGetSelectedRow(Info: TProgramInfo; ExtObject: TObject);
    procedure DoGridSetSelectedRow(Info: TProgramInfo; ExtObject: TObject);
    procedure DoGridGetSelectedColumn(Info: TProgramInfo; ExtObject: TObject);
    procedure DoGridSetSelectedColumn(Info: TProgramInfo; ExtObject: TObject);
    procedure DoGridAddRow(Info: TProgramInfo; ExtObject: TObject);
    procedure DoGridClear(Info: TProgramInfo; ExtObject: TObject);
    procedure DoGridSetText(Info: TProgramInfo; ExtObject: TObject);

    procedure DoGuiEnabled(Info: TProgramInfo);
    procedure DoGuiSetEnabled(Info: TProgramInfo);
    procedure DoGuiLoadLayout(Info: TProgramInfo);
    procedure DoGuiSetTexture(Info: TProgramInfo);
    procedure DoGuiClear(Info: TProgramInfo);
    procedure DoGuiRoot(Info: TProgramInfo);
    procedure DoGuiControlCount(Info: TProgramInfo);
    procedure DoGuiControl(Info: TProgramInfo);
    procedure DoGuiFindControl(Info: TProgramInfo);
    procedure DoGuiControlFromHandle(Info: TProgramInfo);
    procedure DoGuiControlHandle(Info: TProgramInfo);
    procedure DoGuiCreatePanel(Info: TProgramInfo);
    procedure DoGuiCreateButton(Info: TProgramInfo);
    procedure DoGuiCreateCheckBox(Info: TProgramInfo);
    procedure DoGuiCreateEdit(Info: TProgramInfo);
    procedure DoGuiCreateLabel(Info: TProgramInfo);
    procedure DoGuiCreateAdvancedLabel(Info: TProgramInfo);
    procedure DoGuiCreateWindow(Info: TProgramInfo);
    procedure DoGuiCreateScrollbar(Info: TProgramInfo);
    procedure DoGuiCreatePopupMenu(Info: TProgramInfo);
    procedure DoGuiCreateStringGrid(Info: TProgramInfo);
    procedure DoGuiEventControl(Info: TProgramInfo);
    procedure DoGuiEventName(Info: TProgramInfo);
    procedure DoGuiEventHandlerName(Info: TProgramInfo);
    procedure DoGuiEventX(Info: TProgramInfo);
    procedure DoGuiEventY(Info: TProgramInfo);
    procedure DoGuiEventValue(Info: TProgramInfo);
    procedure DoGuiEventIndex(Info: TProgramInfo);
    procedure DoGuiEventButton(Info: TProgramInfo);
    procedure DoGuiEventKey(Info: TProgramInfo);
    procedure DoGuiEventModifiers(Info: TProgramInfo);
    procedure DoGuiEventText(Info: TProgramInfo);
  public
    constructor RegisterGui(AOwner: TComponent; AScript: TDelphiWebScript;
      AManager: TGuiManager);

    procedure BindManager(AManager: TGuiManager);
    procedure BeginEvent(AControl: TGuiControl; const AEventName,
      AHandlerName: string; const AData: TGuiEventData);
    procedure EndEvent;

    property CurrentScriptName: string read FCurrentScriptName
      write FCurrentScriptName;
  end;

implementation

procedure TdwsGuiUnit.RegisterGuiFunction(const AName, AResultType: string;
  const AParamNames, AParamTypes: array of string;
  const AOnEval: TFuncEvalEvent; const AOverloaded: Boolean);
var
  Func: TdwsFunction;
  Param: TdwsParameter;
  I: Integer;
begin
  if Length(AParamNames) <> Length(AParamTypes) then
    raise Exception.Create('GUI function parameter metadata mismatch.');

  Func := Functions.Add;
  Func.Name := AName;
  Func.ResultType := AResultType;
  Func.Overloaded := AOverloaded;
  Func.OnEval := AOnEval;
  for I := 0 to High(AParamNames) do
  begin
    Param := Func.Parameters.Add;
    Param.Name := AParamNames[I];
    Param.DataType := AParamTypes[I];
  end;
end;

procedure TdwsGuiUnit.RegisterGuiClasses;
var
  GuiClass: TdwsClass;

  function AddClass(const AName, AAncestor: string): TdwsClass;
  begin
    Result := Classes.Add;
    Result.Name := AName;
    Result.Ancestor := AAncestor;
  end;

  procedure AddMethod(AClass: TdwsClass; const AName, AResultType: string;
    const AParamNames, AParamTypes: array of string;
    AOnEval: TMethodEvalEvent);
  var
    Method: TdwsMethod;
    Param: TdwsParameter;
    I: Integer;
  begin
    if Length(AParamNames) <> Length(AParamTypes) then
      raise Exception.Create('GUI method parameter metadata mismatch.');
    Method := AClass.Methods.Add;
    Method.Name := AName;
    Method.ResultType := AResultType;
    Method.OnEval := AOnEval;
    for I := 0 to High(AParamNames) do
    begin
      Param := Method.Parameters.Add;
      Param.Name := AParamNames[I];
      Param.DataType := AParamTypes[I];
    end;
  end;

  procedure AddProperty(AClass: TdwsClass; const AName, ADataType,
    AReadAccess, AWriteAccess: string);
  var
    Prop: TdwsProperty;
  begin
    Prop := AClass.Properties.Add;
    Prop.Name := AName;
    Prop.DataType := ADataType;
    Prop.ReadAccess := AReadAccess;
    Prop.WriteAccess := AWriteAccess;
  end;

begin
  GuiClass := AddClass('TGuiControl', '');
  GuiClass.OnCleanUp := DoControlCleanup;
  AddMethod(GuiClass, 'GetHandle', 'Integer', [], [], DoControlGetHandle);
  AddMethod(GuiClass, 'GetName', 'String', [], [], DoControlGetName);
  AddMethod(GuiClass, 'SetName', '', ['Value'], ['String'], DoControlSetName);
  AddMethod(GuiClass, 'GetKind', 'String', [], [], DoControlGetKind);
  AddMethod(GuiClass, 'GetParent', 'TGuiControl', [], [], DoControlGetParent);
  AddMethod(GuiClass, 'SetParent', '', ['Value'], ['TGuiControl'], DoControlSetParent);
  AddMethod(GuiClass, 'GetChildCount', 'Integer', [], [], DoControlGetChildCount);
  AddMethod(GuiClass, 'Child', 'TGuiControl', ['Index'], ['Integer'], DoControlChild);
  AddMethod(GuiClass, 'Delete', '', [], [], DoControlDelete);
  AddMethod(GuiClass, 'GetLeft', 'Float', [], [], DoControlGetLeft);
  AddMethod(GuiClass, 'SetLeft', '', ['Value'], ['Float'], DoControlSetLeft);
  AddMethod(GuiClass, 'GetTop', 'Float', [], [], DoControlGetTop);
  AddMethod(GuiClass, 'SetTop', '', ['Value'], ['Float'], DoControlSetTop);
  AddMethod(GuiClass, 'GetWidth', 'Float', [], [], DoControlGetWidth);
  AddMethod(GuiClass, 'SetWidth', '', ['Value'], ['Float'], DoControlSetWidth);
  AddMethod(GuiClass, 'GetHeight', 'Float', [], [], DoControlGetHeight);
  AddMethod(GuiClass, 'SetHeight', '', ['Value'], ['Float'], DoControlSetHeight);
  AddMethod(GuiClass, 'GetVisible', 'Boolean', [], [], DoControlGetVisible);
  AddMethod(GuiClass, 'SetVisible', '', ['Value'], ['Boolean'], DoControlSetVisible);
  AddMethod(GuiClass, 'GetScale', 'Float', [], [], DoControlGetScale);
  AddMethod(GuiClass, 'SetScale', '', ['Value'], ['Float'], DoControlSetScale);
  AddMethod(GuiClass, 'GetTint', 'TVector4', [], [], DoControlGetTint);
  AddMethod(GuiClass, 'SetTint', '', ['Value'], ['TVector4'], DoControlSetTint);
  AddMethod(GuiClass, 'GetLayoutName', 'String', [], [], DoControlGetLayoutName);
  AddMethod(GuiClass, 'SetLayoutName', '', ['Value'], ['String'], DoControlSetLayoutName);
  AddMethod(GuiClass, 'SetBounds', '', ['Left', 'Top', 'Width', 'Height'],
    ['Float', 'Float', 'Float', 'Float'], DoControlSetBounds);
  AddMethod(GuiClass, 'Show', '', [], [], DoControlShow);
  AddMethod(GuiClass, 'Hide', '', [], [], DoControlHide);
  AddMethod(GuiClass, 'BringToFront', '', [], [], DoControlBringToFront);
  AddMethod(GuiClass, 'SendToBack', '', [], [], DoControlSendToBack);
  AddMethod(GuiClass, 'EventHandler', 'String', ['EventName'], ['String'],
    DoControlEventHandler);
  AddMethod(GuiClass, 'SetEventHandler', '', ['EventName', 'HandlerName'],
    ['String', 'String'], DoControlSetEventHandler);
  AddProperty(GuiClass, 'Handle', 'Integer', 'GetHandle', '');
  AddProperty(GuiClass, 'Name', 'String', 'GetName', 'SetName');
  AddProperty(GuiClass, 'Kind', 'String', 'GetKind', '');
  AddProperty(GuiClass, 'Parent', 'TGuiControl', 'GetParent', 'SetParent');
  AddProperty(GuiClass, 'ChildCount', 'Integer', 'GetChildCount', '');
  AddProperty(GuiClass, 'Left', 'Float', 'GetLeft', 'SetLeft');
  AddProperty(GuiClass, 'Top', 'Float', 'GetTop', 'SetTop');
  AddProperty(GuiClass, 'Width', 'Float', 'GetWidth', 'SetWidth');
  AddProperty(GuiClass, 'Height', 'Float', 'GetHeight', 'SetHeight');
  AddProperty(GuiClass, 'Visible', 'Boolean', 'GetVisible', 'SetVisible');
  AddProperty(GuiClass, 'Scale', 'Float', 'GetScale', 'SetScale');
  AddProperty(GuiClass, 'Tint', 'TVector4', 'GetTint', 'SetTint');
  AddProperty(GuiClass, 'LayoutName', 'String', 'GetLayoutName', 'SetLayoutName');

  GuiClass := AddClass('TGuiTextControl', 'TGuiControl');
  AddMethod(GuiClass, 'GetCaption', 'String', [], [], DoTextGetCaption);
  AddMethod(GuiClass, 'SetCaption', '', ['Value'], ['String'], DoTextSetCaption);
  AddProperty(GuiClass, 'Caption', 'String', 'GetCaption', 'SetCaption');

  AddClass('TGuiPanel', 'TGuiControl');

  GuiClass := AddClass('TGuiButton', 'TGuiTextControl');
  AddMethod(GuiClass, 'GetPressed', 'Boolean', [], [], DoButtonGetPressed);
  AddMethod(GuiClass, 'SetPressed', '', ['Value'], ['Boolean'], DoButtonSetPressed);
  AddMethod(GuiClass, 'GetAllowUp', 'Boolean', [], [], DoButtonGetAllowUp);
  AddMethod(GuiClass, 'SetAllowUp', '', ['Value'], ['Boolean'], DoButtonSetAllowUp);
  AddMethod(GuiClass, 'GetGroup', 'Integer', [], [], DoButtonGetGroup);
  AddMethod(GuiClass, 'SetGroup', '', ['Value'], ['Integer'], DoButtonSetGroup);
  AddMethod(GuiClass, 'GetPressedLayoutName', 'String', [], [],
    DoButtonGetPressedLayoutName);
  AddMethod(GuiClass, 'SetPressedLayoutName', '', ['Value'], ['String'],
    DoButtonSetPressedLayoutName);
  AddProperty(GuiClass, 'Pressed', 'Boolean', 'GetPressed', 'SetPressed');
  AddProperty(GuiClass, 'AllowUp', 'Boolean', 'GetAllowUp', 'SetAllowUp');
  AddProperty(GuiClass, 'Group', 'Integer', 'GetGroup', 'SetGroup');
  AddProperty(GuiClass, 'PressedLayoutName', 'String',
    'GetPressedLayoutName', 'SetPressedLayoutName');

  GuiClass := AddClass('TGuiCheckBox', 'TGuiControl');
  AddMethod(GuiClass, 'GetChecked', 'Boolean', [], [], DoCheckBoxGetChecked);
  AddMethod(GuiClass, 'SetChecked', '', ['Value'], ['Boolean'], DoCheckBoxSetChecked);
  AddMethod(GuiClass, 'GetGroup', 'Integer', [], [], DoCheckBoxGetGroup);
  AddMethod(GuiClass, 'SetGroup', '', ['Value'], ['Integer'], DoCheckBoxSetGroup);
  AddMethod(GuiClass, 'GetCheckedLayoutName', 'String', [], [],
    DoCheckBoxGetCheckedLayoutName);
  AddMethod(GuiClass, 'SetCheckedLayoutName', '', ['Value'], ['String'],
    DoCheckBoxSetCheckedLayoutName);
  AddProperty(GuiClass, 'Checked', 'Boolean', 'GetChecked', 'SetChecked');
  AddProperty(GuiClass, 'Group', 'Integer', 'GetGroup', 'SetGroup');
  AddProperty(GuiClass, 'CheckedLayoutName', 'String',
    'GetCheckedLayoutName', 'SetCheckedLayoutName');

  GuiClass := AddClass('TGuiEdit', 'TGuiTextControl');
  AddMethod(GuiClass, 'GetReadOnly', 'Boolean', [], [], DoEditGetReadOnly);
  AddMethod(GuiClass, 'SetReadOnly', '', ['Value'], ['Boolean'], DoEditSetReadOnly);
  AddMethod(GuiClass, 'GetSelStart', 'Integer', [], [], DoEditGetSelStart);
  AddMethod(GuiClass, 'SetSelStart', '', ['Value'], ['Integer'], DoEditSetSelStart);
  AddProperty(GuiClass, 'ReadOnly', 'Boolean', 'GetReadOnly', 'SetReadOnly');
  AddProperty(GuiClass, 'SelStart', 'Integer', 'GetSelStart', 'SetSelStart');

  GuiClass := AddClass('TGuiLabel', 'TGuiTextControl');
  AddMethod(GuiClass, 'GetAlignment', 'Integer', [], [], DoLabelGetAlignment);
  AddMethod(GuiClass, 'SetAlignment', '', ['Value'], ['Integer'], DoLabelSetAlignment);
  AddMethod(GuiClass, 'GetTextLayout', 'Integer', [], [], DoLabelGetTextLayout);
  AddMethod(GuiClass, 'SetTextLayout', '', ['Value'], ['Integer'], DoLabelSetTextLayout);
  AddProperty(GuiClass, 'Alignment', 'Integer', 'GetAlignment', 'SetAlignment');
  AddProperty(GuiClass, 'TextLayout', 'Integer', 'GetTextLayout', 'SetTextLayout');
  AddClass('TGuiAdvancedLabel', 'TGuiLabel');

  GuiClass := AddClass('TGuiWindow', 'TGuiTextControl');
  AddMethod(GuiClass, 'Close', '', [], [], DoWindowClose);
  AddMethod(GuiClass, 'GetTitleOffset', 'Float', [], [], DoWindowGetTitleOffset);
  AddMethod(GuiClass, 'SetTitleOffset', '', ['Value'], ['Float'],
    DoWindowSetTitleOffset);
  AddProperty(GuiClass, 'TitleOffset', 'Float',
    'GetTitleOffset', 'SetTitleOffset');

  GuiClass := AddClass('TGuiScrollbar', 'TGuiTextControl');
  AddMethod(GuiClass, 'GetMin', 'Float', [], [], DoScrollbarGetMin);
  AddMethod(GuiClass, 'SetMin', '', ['Value'], ['Float'], DoScrollbarSetMin);
  AddMethod(GuiClass, 'GetMax', 'Float', [], [], DoScrollbarGetMax);
  AddMethod(GuiClass, 'SetMax', '', ['Value'], ['Float'], DoScrollbarSetMax);
  AddMethod(GuiClass, 'GetPosition', 'Float', [], [], DoScrollbarGetPosition);
  AddMethod(GuiClass, 'SetPosition', '', ['Value'], ['Float'],
    DoScrollbarSetPosition);
  AddMethod(GuiClass, 'GetPageSize', 'Float', [], [], DoScrollbarGetPageSize);
  AddMethod(GuiClass, 'SetPageSize', '', ['Value'], ['Float'],
    DoScrollbarSetPageSize);
  AddMethod(GuiClass, 'GetStep', 'Float', [], [], DoScrollbarGetStep);
  AddMethod(GuiClass, 'SetStep', '', ['Value'], ['Float'], DoScrollbarSetStep);
  AddMethod(GuiClass, 'GetHorizontal', 'Boolean', [], [],
    DoScrollbarGetHorizontal);
  AddMethod(GuiClass, 'SetHorizontal', '', ['Value'], ['Boolean'],
    DoScrollbarSetHorizontal);
  AddMethod(GuiClass, 'GetLocked', 'Boolean', [], [], DoScrollbarGetLocked);
  AddMethod(GuiClass, 'SetLocked', '', ['Value'], ['Boolean'], DoScrollbarSetLocked);
  AddMethod(GuiClass, 'StepUp', '', [], [], DoScrollbarStepUp);
  AddMethod(GuiClass, 'StepDown', '', [], [], DoScrollbarStepDown);
  AddMethod(GuiClass, 'PageUp', '', [], [], DoScrollbarPageUp);
  AddMethod(GuiClass, 'PageDown', '', [], [], DoScrollbarPageDown);
  AddProperty(GuiClass, 'Min', 'Float', 'GetMin', 'SetMin');
  AddProperty(GuiClass, 'Max', 'Float', 'GetMax', 'SetMax');
  AddProperty(GuiClass, 'Position', 'Float', 'GetPosition', 'SetPosition');
  AddProperty(GuiClass, 'PageSize', 'Float', 'GetPageSize', 'SetPageSize');
  AddProperty(GuiClass, 'Step', 'Float', 'GetStep', 'SetStep');
  AddProperty(GuiClass, 'Horizontal', 'Boolean', 'GetHorizontal', 'SetHorizontal');
  AddProperty(GuiClass, 'Locked', 'Boolean', 'GetLocked', 'SetLocked');

  GuiClass := AddClass('TGuiPopupMenu', 'TGuiTextControl');
  AddMethod(GuiClass, 'GetItemsText', 'String', [], [], DoPopupGetItemsText);
  AddMethod(GuiClass, 'SetItemsText', '', ['Value'], ['String'], DoPopupSetItemsText);
  AddMethod(GuiClass, 'GetSelectedIndex', 'Integer', [], [],
    DoPopupGetSelectedIndex);
  AddMethod(GuiClass, 'SetSelectedIndex', '', ['Value'], ['Integer'],
    DoPopupSetSelectedIndex);
  AddMethod(GuiClass, 'AddItem', 'Integer', ['Text'], ['String'], DoPopupAddItem);
  AddMethod(GuiClass, 'Clear', '', [], [], DoPopupClear);
  AddMethod(GuiClass, 'Popup', '', ['X', 'Y'], ['Integer', 'Integer'], DoPopupPopup);
  AddProperty(GuiClass, 'ItemsText', 'String', 'GetItemsText', 'SetItemsText');
  AddProperty(GuiClass, 'SelectedIndex', 'Integer',
    'GetSelectedIndex', 'SetSelectedIndex');

  GuiClass := AddClass('TGuiStringGrid', 'TGuiTextControl');
  AddMethod(GuiClass, 'GetColumnsText', 'String', [], [], DoGridGetColumnsText);
  AddMethod(GuiClass, 'SetColumnsText', '', ['Value'], ['String'],
    DoGridSetColumnsText);
  AddMethod(GuiClass, 'GetRowCount', 'Integer', [], [], DoGridGetRowCount);
  AddMethod(GuiClass, 'GetSelectedRow', 'Integer', [], [], DoGridGetSelectedRow);
  AddMethod(GuiClass, 'SetSelectedRow', '', ['Value'], ['Integer'],
    DoGridSetSelectedRow);
  AddMethod(GuiClass, 'GetSelectedColumn', 'Integer', [], [],
    DoGridGetSelectedColumn);
  AddMethod(GuiClass, 'SetSelectedColumn', '', ['Value'], ['Integer'],
    DoGridSetSelectedColumn);
  AddMethod(GuiClass, 'AddRow', 'Integer', ['Text'], ['String'], DoGridAddRow);
  AddMethod(GuiClass, 'Clear', '', [], [], DoGridClear);
  AddMethod(GuiClass, 'SetText', '', ['Value'], ['String'], DoGridSetText);
  AddProperty(GuiClass, 'ColumnsText', 'String',
    'GetColumnsText', 'SetColumnsText');
  AddProperty(GuiClass, 'RowCount', 'Integer', 'GetRowCount', '');
  AddProperty(GuiClass, 'SelectedRow', 'Integer',
    'GetSelectedRow', 'SetSelectedRow');
  AddProperty(GuiClass, 'SelectedColumn', 'Integer',
    'GetSelectedColumn', 'SetSelectedColumn');
end;

procedure TdwsGuiUnit.RequireManager;
begin
  if FManager = nil then
    raise Exception.Create('The engine GUI manager is not available.');
end;

function TdwsGuiUnit.RequireControl(ExtObject: TObject): TGuiControl;
begin
  RequireManager;
  if (ExtObject is TGuiControl) and
     FManager.ContainsControl(TGuiControl(ExtObject)) then
    Exit(TGuiControl(ExtObject));
  raise Exception.Create('Invalid or destroyed TGuiControl script object.');
end;

function TdwsGuiUnit.ParamAsControl(Info: TProgramInfo;
  AIndex: Integer): TGuiControl;
var
  Obj: TObject;
begin
  Obj := Info.ParamAsObject[AIndex];
  if Obj is TGuiControl then
    Result := TGuiControl(Obj)
  else
    Result := nil;
end;

procedure TdwsGuiUnit.SetResultControl(Info: TProgramInfo;
  AControl: TGuiControl);
begin
  if AControl <> nil then
    Info.ResultAsVariant := Info.RegisterExternalObject(AControl, False, False)
  else
    Info.ResultAsVariant := IScriptObj(nil);
end;

function TdwsGuiUnit.InfoAsVector4(const AInfo: IInfo): TVector4;
begin
  Result := Vector4(
    AInfo.Member['X'].ValueAsFloat,
    AInfo.Member['Y'].ValueAsFloat,
    AInfo.Member['Z'].ValueAsFloat,
    AInfo.Member['W'].ValueAsFloat);
end;

procedure TdwsGuiUnit.SetResultVector4(Info: TProgramInfo;
  const AValue: TVector4);
begin
  Info.ResultVars.Member['X'].Value := AValue.X;
  Info.ResultVars.Member['Y'].Value := AValue.Y;
  Info.ResultVars.Member['Z'].Value := AValue.Z;
  Info.ResultVars.Member['W'].Value := AValue.W;
end;

function TdwsGuiUnit.ResolveGuiFileName(const AFileName: string): string;
begin
  if TPath.IsPathRooted(AFileName) then
    Result := AFileName
  else
    Result := TEnginePaths.EngineGUI(AFileName);
end;

procedure TdwsGuiUnit.DoControlCleanup(ExternalObject: TObject);
begin
  // GUI controls are owned by TGuiManager, not by DWS wrapper lifetime.
end;

procedure TdwsGuiUnit.DoControlGetHandle(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsInteger := FManager.HandleOf(RequireControl(ExtObject));
end;

procedure TdwsGuiUnit.DoControlGetName(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsString := RequireControl(ExtObject).Name;
end;

procedure TdwsGuiUnit.DoControlSetName(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireControl(ExtObject).Name := Info.ParamAsString[0];
end;

procedure TdwsGuiUnit.DoControlGetKind(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsString := FManager.KindName(RequireControl(ExtObject));
end;

procedure TdwsGuiUnit.DoControlGetParent(Info: TProgramInfo; ExtObject: TObject);
begin
  SetResultControl(Info, RequireControl(ExtObject).Parent);
end;

procedure TdwsGuiUnit.DoControlSetParent(Info: TProgramInfo; ExtObject: TObject);
begin
  FManager.SetParent(RequireControl(ExtObject), ParamAsControl(Info, 0));
end;

procedure TdwsGuiUnit.DoControlGetChildCount(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsInteger := RequireControl(ExtObject).ChildCount;
end;

procedure TdwsGuiUnit.DoControlChild(Info: TProgramInfo; ExtObject: TObject);
var
  Control: TGuiControl;
  Index: Integer;
begin
  Control := RequireControl(ExtObject);
  Index := Info.ParamAsInteger[0];
  if (Index >= 0) and (Index < Control.ChildCount) then
    SetResultControl(Info, Control.Children[Index])
  else
    SetResultControl(Info, nil);
end;

procedure TdwsGuiUnit.DoControlDelete(Info: TProgramInfo; ExtObject: TObject);
begin
  FManager.DeleteControl(RequireControl(ExtObject));
end;

procedure TdwsGuiUnit.DoControlGetLeft(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsFloat := RequireControl(ExtObject).Left;
end;

procedure TdwsGuiUnit.DoControlSetLeft(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireControl(ExtObject).Left := Info.ParamAsFloat[0];
end;

procedure TdwsGuiUnit.DoControlGetTop(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsFloat := RequireControl(ExtObject).Top;
end;

procedure TdwsGuiUnit.DoControlSetTop(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireControl(ExtObject).Top := Info.ParamAsFloat[0];
end;

procedure TdwsGuiUnit.DoControlGetWidth(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsFloat := RequireControl(ExtObject).Width;
end;

procedure TdwsGuiUnit.DoControlSetWidth(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireControl(ExtObject).Width := Max(0.0, Info.ParamAsFloat[0]);
end;

procedure TdwsGuiUnit.DoControlGetHeight(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsFloat := RequireControl(ExtObject).Height;
end;

procedure TdwsGuiUnit.DoControlSetHeight(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireControl(ExtObject).Height := Max(0.0, Info.ParamAsFloat[0]);
end;

procedure TdwsGuiUnit.DoControlGetVisible(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsBoolean := RequireControl(ExtObject).Visible;
end;

procedure TdwsGuiUnit.DoControlSetVisible(Info: TProgramInfo; ExtObject: TObject);
begin
  FManager.SetVisible(RequireControl(ExtObject), Info.ParamAsBoolean[0]);
end;

procedure TdwsGuiUnit.DoControlGetScale(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsFloat := RequireControl(ExtObject).Scale;
end;

procedure TdwsGuiUnit.DoControlSetScale(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireControl(ExtObject).Scale := Max(0.0, Info.ParamAsFloat[0]);
end;

procedure TdwsGuiUnit.DoControlGetTint(Info: TProgramInfo; ExtObject: TObject);
begin
  SetResultVector4(Info, RequireControl(ExtObject).Tint);
end;

procedure TdwsGuiUnit.DoControlSetTint(Info: TProgramInfo; ExtObject: TObject);
begin
  RequireControl(ExtObject).Tint := InfoAsVector4(Info.Params[0]);
end;

procedure TdwsGuiUnit.DoControlGetLayoutName(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsString := RequireControl(ExtObject).ComponentName;
end;

procedure TdwsGuiUnit.DoControlSetLayoutName(Info: TProgramInfo;
  ExtObject: TObject);
begin
  RequireControl(ExtObject).ComponentName := Info.ParamAsString[0];
end;

procedure TdwsGuiUnit.DoControlSetBounds(Info: TProgramInfo; ExtObject: TObject);
var
  Control: TGuiControl;
begin
  Control := RequireControl(ExtObject);
  Control.Left := Info.ParamAsFloat[0];
  Control.Top := Info.ParamAsFloat[1];
  Control.Width := Max(0.0, Info.ParamAsFloat[2]);
  Control.Height := Max(0.0, Info.ParamAsFloat[3]);
end;

procedure TdwsGuiUnit.DoControlShow(Info: TProgramInfo; ExtObject: TObject);
begin
  FManager.SetVisible(RequireControl(ExtObject), True);
end;

procedure TdwsGuiUnit.DoControlHide(Info: TProgramInfo; ExtObject: TObject);
begin
  FManager.SetVisible(RequireControl(ExtObject), False);
end;

procedure TdwsGuiUnit.DoControlBringToFront(Info: TProgramInfo;
  ExtObject: TObject);
begin
  FManager.BringToFront(RequireControl(ExtObject));
end;

procedure TdwsGuiUnit.DoControlSendToBack(Info: TProgramInfo;
  ExtObject: TObject);
begin
  FManager.SendToBack(RequireControl(ExtObject));
end;

procedure TdwsGuiUnit.DoControlEventHandler(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsString := FManager.EventHandler(RequireControl(ExtObject),
    Info.ParamAsString[0]);
end;

procedure TdwsGuiUnit.DoControlSetEventHandler(Info: TProgramInfo;
  ExtObject: TObject);
begin
  FManager.SetEventHandler(RequireControl(ExtObject), Info.ParamAsString[0],
    Info.ParamAsString[1], FCurrentScriptName);
end;

procedure TdwsGuiUnit.DoTextGetCaption(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsString := TGuiBaseTextControl(RequireControl(ExtObject)).Caption;
end;

procedure TdwsGuiUnit.DoTextSetCaption(Info: TProgramInfo; ExtObject: TObject);
begin
  TGuiBaseTextControl(RequireControl(ExtObject)).Caption :=
    Info.ParamAsString[0];
end;

procedure TdwsGuiUnit.DoButtonGetPressed(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsBoolean := TGuiButton(RequireControl(ExtObject)).Pressed;
end;

procedure TdwsGuiUnit.DoButtonSetPressed(Info: TProgramInfo; ExtObject: TObject);
begin
  TGuiButton(RequireControl(ExtObject)).Pressed := Info.ParamAsBoolean[0];
end;

procedure TdwsGuiUnit.DoButtonGetAllowUp(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsBoolean := TGuiButton(RequireControl(ExtObject)).AllowUp;
end;

procedure TdwsGuiUnit.DoButtonSetAllowUp(Info: TProgramInfo; ExtObject: TObject);
begin
  TGuiButton(RequireControl(ExtObject)).AllowUp := Info.ParamAsBoolean[0];
end;

procedure TdwsGuiUnit.DoButtonGetGroup(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsInteger := TGuiButton(RequireControl(ExtObject)).Group;
end;

procedure TdwsGuiUnit.DoButtonSetGroup(Info: TProgramInfo; ExtObject: TObject);
begin
  TGuiButton(RequireControl(ExtObject)).Group := Info.ParamAsInteger[0];
end;

procedure TdwsGuiUnit.DoButtonGetPressedLayoutName(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsString :=
    TGuiButton(RequireControl(ExtObject)).PressedLayoutName;
end;

procedure TdwsGuiUnit.DoButtonSetPressedLayoutName(Info: TProgramInfo;
  ExtObject: TObject);
begin
  TGuiButton(RequireControl(ExtObject)).PressedLayoutName :=
    Info.ParamAsString[0];
end;

procedure TdwsGuiUnit.DoCheckBoxGetChecked(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsBoolean := TGuiCheckBox(RequireControl(ExtObject)).Checked;
end;

procedure TdwsGuiUnit.DoCheckBoxSetChecked(Info: TProgramInfo;
  ExtObject: TObject);
begin
  TGuiCheckBox(RequireControl(ExtObject)).Checked := Info.ParamAsBoolean[0];
end;

procedure TdwsGuiUnit.DoCheckBoxGetGroup(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsInteger := TGuiCheckBox(RequireControl(ExtObject)).Group;
end;

procedure TdwsGuiUnit.DoCheckBoxSetGroup(Info: TProgramInfo;
  ExtObject: TObject);
begin
  TGuiCheckBox(RequireControl(ExtObject)).Group := Info.ParamAsInteger[0];
end;

procedure TdwsGuiUnit.DoCheckBoxGetCheckedLayoutName(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsString :=
    TGuiCheckBox(RequireControl(ExtObject)).CheckedLayoutName;
end;

procedure TdwsGuiUnit.DoCheckBoxSetCheckedLayoutName(Info: TProgramInfo;
  ExtObject: TObject);
begin
  TGuiCheckBox(RequireControl(ExtObject)).CheckedLayoutName :=
    Info.ParamAsString[0];
end;

procedure TdwsGuiUnit.DoEditGetReadOnly(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsBoolean := TGuiEdit(RequireControl(ExtObject)).ReadOnly;
end;

procedure TdwsGuiUnit.DoEditSetReadOnly(Info: TProgramInfo; ExtObject: TObject);
begin
  TGuiEdit(RequireControl(ExtObject)).ReadOnly := Info.ParamAsBoolean[0];
end;

procedure TdwsGuiUnit.DoEditGetSelStart(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsInteger := TGuiEdit(RequireControl(ExtObject)).SelStart;
end;

procedure TdwsGuiUnit.DoEditSetSelStart(Info: TProgramInfo; ExtObject: TObject);
begin
  TGuiEdit(RequireControl(ExtObject)).SelStart := Info.ParamAsInteger[0];
end;

procedure TdwsGuiUnit.DoLabelGetAlignment(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsInteger := Ord(TGuiLabel(RequireControl(ExtObject)).Alignment);
end;

procedure TdwsGuiUnit.DoLabelSetAlignment(Info: TProgramInfo;
  ExtObject: TObject);
begin
  TGuiLabel(RequireControl(ExtObject)).Alignment :=
    TAlignment(EnsureRange(Info.ParamAsInteger[0],
      Ord(Low(TAlignment)), Ord(High(TAlignment))));
end;

procedure TdwsGuiUnit.DoLabelGetTextLayout(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsInteger := Ord(TGuiLabel(RequireControl(ExtObject)).TextLayout);
end;

procedure TdwsGuiUnit.DoLabelSetTextLayout(Info: TProgramInfo;
  ExtObject: TObject);
begin
  TGuiLabel(RequireControl(ExtObject)).TextLayout :=
    TTextLayout(EnsureRange(Info.ParamAsInteger[0],
      Ord(Low(TTextLayout)), Ord(High(TTextLayout))));
end;

procedure TdwsGuiUnit.DoWindowClose(Info: TProgramInfo; ExtObject: TObject);
begin
  TGuiForm(RequireControl(ExtObject)).Close;
end;

procedure TdwsGuiUnit.DoWindowGetTitleOffset(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsFloat := TGuiForm(RequireControl(ExtObject)).TitleOffset;
end;

procedure TdwsGuiUnit.DoWindowSetTitleOffset(Info: TProgramInfo;
  ExtObject: TObject);
begin
  TGuiForm(RequireControl(ExtObject)).TitleOffset := Info.ParamAsFloat[0];
end;

procedure TdwsGuiUnit.DoScrollbarGetMin(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsFloat := TGuiScrollbar(RequireControl(ExtObject)).Min;
end;

procedure TdwsGuiUnit.DoScrollbarSetMin(Info: TProgramInfo; ExtObject: TObject);
begin
  TGuiScrollbar(RequireControl(ExtObject)).Min := Info.ParamAsFloat[0];
end;

procedure TdwsGuiUnit.DoScrollbarGetMax(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsFloat := TGuiScrollbar(RequireControl(ExtObject)).Max;
end;

procedure TdwsGuiUnit.DoScrollbarSetMax(Info: TProgramInfo; ExtObject: TObject);
begin
  TGuiScrollbar(RequireControl(ExtObject)).Max := Info.ParamAsFloat[0];
end;

procedure TdwsGuiUnit.DoScrollbarGetPosition(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsFloat := TGuiScrollbar(RequireControl(ExtObject)).Pos;
end;

procedure TdwsGuiUnit.DoScrollbarSetPosition(Info: TProgramInfo;
  ExtObject: TObject);
begin
  TGuiScrollbar(RequireControl(ExtObject)).Pos := Info.ParamAsFloat[0];
end;

procedure TdwsGuiUnit.DoScrollbarGetPageSize(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsFloat := TGuiScrollbar(RequireControl(ExtObject)).PageSize;
end;

procedure TdwsGuiUnit.DoScrollbarSetPageSize(Info: TProgramInfo;
  ExtObject: TObject);
begin
  TGuiScrollbar(RequireControl(ExtObject)).PageSize := Info.ParamAsFloat[0];
end;

procedure TdwsGuiUnit.DoScrollbarGetStep(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsFloat := TGuiScrollbar(RequireControl(ExtObject)).Step;
end;

procedure TdwsGuiUnit.DoScrollbarSetStep(Info: TProgramInfo; ExtObject: TObject);
begin
  TGuiScrollbar(RequireControl(ExtObject)).Step := Info.ParamAsFloat[0];
end;

procedure TdwsGuiUnit.DoScrollbarGetHorizontal(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsBoolean := TGuiScrollbar(RequireControl(ExtObject)).Horizontal;
end;

procedure TdwsGuiUnit.DoScrollbarSetHorizontal(Info: TProgramInfo;
  ExtObject: TObject);
begin
  TGuiScrollbar(RequireControl(ExtObject)).Horizontal :=
    Info.ParamAsBoolean[0];
end;

procedure TdwsGuiUnit.DoScrollbarGetLocked(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsBoolean := TGuiScrollbar(RequireControl(ExtObject)).Locked;
end;

procedure TdwsGuiUnit.DoScrollbarSetLocked(Info: TProgramInfo;
  ExtObject: TObject);
begin
  TGuiScrollbar(RequireControl(ExtObject)).Locked := Info.ParamAsBoolean[0];
end;

procedure TdwsGuiUnit.DoScrollbarStepUp(Info: TProgramInfo; ExtObject: TObject);
begin
  TGuiScrollbar(RequireControl(ExtObject)).StepUp;
end;

procedure TdwsGuiUnit.DoScrollbarStepDown(Info: TProgramInfo;
  ExtObject: TObject);
begin
  TGuiScrollbar(RequireControl(ExtObject)).StepDown;
end;

procedure TdwsGuiUnit.DoScrollbarPageUp(Info: TProgramInfo; ExtObject: TObject);
begin
  TGuiScrollbar(RequireControl(ExtObject)).PageUp;
end;

procedure TdwsGuiUnit.DoScrollbarPageDown(Info: TProgramInfo;
  ExtObject: TObject);
begin
  TGuiScrollbar(RequireControl(ExtObject)).PageDown;
end;

procedure TdwsGuiUnit.DoPopupGetItemsText(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsString := TGuiPopupMenu(RequireControl(ExtObject)).MenuItems.Text;
end;

procedure TdwsGuiUnit.DoPopupSetItemsText(Info: TProgramInfo;
  ExtObject: TObject);
begin
  TGuiPopupMenu(RequireControl(ExtObject)).MenuItems.Text :=
    Info.ParamAsString[0];
end;

procedure TdwsGuiUnit.DoPopupGetSelectedIndex(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsInteger := TGuiPopupMenu(RequireControl(ExtObject)).SelIndex;
end;

procedure TdwsGuiUnit.DoPopupSetSelectedIndex(Info: TProgramInfo;
  ExtObject: TObject);
begin
  TGuiPopupMenu(RequireControl(ExtObject)).SelIndex := Info.ParamAsInteger[0];
end;

procedure TdwsGuiUnit.DoPopupAddItem(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsInteger :=
    TGuiPopupMenu(RequireControl(ExtObject)).MenuItems.Add(
      Info.ParamAsString[0]);
end;

procedure TdwsGuiUnit.DoPopupClear(Info: TProgramInfo; ExtObject: TObject);
begin
  TGuiPopupMenu(RequireControl(ExtObject)).MenuItems.Clear;
end;

procedure TdwsGuiUnit.DoPopupPopup(Info: TProgramInfo; ExtObject: TObject);
begin
  TGuiPopupMenu(RequireControl(ExtObject)).Popup(
    Info.ParamAsInteger[0], Info.ParamAsInteger[1]);
end;

procedure TdwsGuiUnit.DoGridGetColumnsText(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsString := TGuiStringGrid(RequireControl(ExtObject)).Columns.Text;
end;

procedure TdwsGuiUnit.DoGridSetColumnsText(Info: TProgramInfo;
  ExtObject: TObject);
begin
  TGuiStringGrid(RequireControl(ExtObject)).Columns.Text :=
    Info.ParamAsString[0];
end;

procedure TdwsGuiUnit.DoGridGetRowCount(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsInteger := TGuiStringGrid(RequireControl(ExtObject)).RowCount;
end;

procedure TdwsGuiUnit.DoGridGetSelectedRow(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsInteger := TGuiStringGrid(RequireControl(ExtObject)).SelRow;
end;

procedure TdwsGuiUnit.DoGridSetSelectedRow(Info: TProgramInfo;
  ExtObject: TObject);
begin
  TGuiStringGrid(RequireControl(ExtObject)).SelRow := Info.ParamAsInteger[0];
end;

procedure TdwsGuiUnit.DoGridGetSelectedColumn(Info: TProgramInfo;
  ExtObject: TObject);
begin
  Info.ResultAsInteger := TGuiStringGrid(RequireControl(ExtObject)).SelCol;
end;

procedure TdwsGuiUnit.DoGridSetSelectedColumn(Info: TProgramInfo;
  ExtObject: TObject);
begin
  TGuiStringGrid(RequireControl(ExtObject)).SelCol := Info.ParamAsInteger[0];
end;

procedure TdwsGuiUnit.DoGridAddRow(Info: TProgramInfo; ExtObject: TObject);
begin
  Info.ResultAsInteger := TGuiStringGrid(RequireControl(ExtObject)).Add(
    Info.ParamAsString[0]);
end;

procedure TdwsGuiUnit.DoGridClear(Info: TProgramInfo; ExtObject: TObject);
begin
  TGuiStringGrid(RequireControl(ExtObject)).Clear;
end;

procedure TdwsGuiUnit.DoGridSetText(Info: TProgramInfo; ExtObject: TObject);
begin
  TGuiStringGrid(RequireControl(ExtObject)).SetText(Info.ParamAsString[0]);
end;

procedure TdwsGuiUnit.DoGuiEnabled(Info: TProgramInfo);
begin
  RequireManager;
  Info.ResultAsBoolean := FManager.Enabled;
end;

procedure TdwsGuiUnit.DoGuiSetEnabled(Info: TProgramInfo);
begin
  RequireManager;
  FManager.Enabled := Info.ParamAsBoolean[0];
end;

procedure TdwsGuiUnit.DoGuiLoadLayout(Info: TProgramInfo);
var
  LayoutFileName: string;
  TextureFileName: string;
begin
  RequireManager;
  LayoutFileName := ResolveGuiFileName(Info.ParamAsString[0]);
  TextureFileName := '';
  if Info.ParamCount > 1 then
    TextureFileName := ResolveGuiFileName(Info.ParamAsString[1]);
  Info.ResultAsBoolean := FManager.LoadLayout(LayoutFileName, TextureFileName);
end;

procedure TdwsGuiUnit.DoGuiSetTexture(Info: TProgramInfo);
begin
  RequireManager;
  Info.ResultAsBoolean :=
    FManager.SetTexture(ResolveGuiFileName(Info.ParamAsString[0]));
end;

procedure TdwsGuiUnit.DoGuiClear(Info: TProgramInfo);
begin
  RequireManager;
  FManager.Clear;
end;

procedure TdwsGuiUnit.DoGuiRoot(Info: TProgramInfo);
begin
  RequireManager;
  SetResultControl(Info, FManager.Root);
end;

procedure TdwsGuiUnit.DoGuiControlCount(Info: TProgramInfo);
begin
  RequireManager;
  Info.ResultAsInteger := FManager.Count;
end;

procedure TdwsGuiUnit.DoGuiControl(Info: TProgramInfo);
begin
  RequireManager;
  SetResultControl(Info, FManager.ControlAt(Info.ParamAsInteger[0]));
end;

procedure TdwsGuiUnit.DoGuiFindControl(Info: TProgramInfo);
begin
  RequireManager;
  SetResultControl(Info, FManager.FindControl(Info.ParamAsString[0]));
end;

procedure TdwsGuiUnit.DoGuiControlFromHandle(Info: TProgramInfo);
begin
  RequireManager;
  SetResultControl(Info, FManager.ControlFromHandle(Info.ParamAsInteger[0]));
end;

procedure TdwsGuiUnit.DoGuiControlHandle(Info: TProgramInfo);
begin
  RequireManager;
  Info.ResultAsInteger := FManager.HandleOf(ParamAsControl(Info, 0));
end;

function GuiParentFromInfo(AUnit: TdwsGuiUnit; Info: TProgramInfo): TGuiControl;
begin
  if Info.ParamCount > 1 then
    Result := AUnit.ParamAsControl(Info, 1)
  else
    Result := nil;
end;

procedure TdwsGuiUnit.DoGuiCreatePanel(Info: TProgramInfo);
begin
  RequireManager;
  SetResultControl(Info, FManager.CreatePanel(Info.ParamAsString[0],
    GuiParentFromInfo(Self, Info)));
end;

procedure TdwsGuiUnit.DoGuiCreateButton(Info: TProgramInfo);
begin
  RequireManager;
  SetResultControl(Info, FManager.CreateButton(Info.ParamAsString[0],
    GuiParentFromInfo(Self, Info)));
end;

procedure TdwsGuiUnit.DoGuiCreateCheckBox(Info: TProgramInfo);
begin
  RequireManager;
  SetResultControl(Info, FManager.CreateCheckBox(Info.ParamAsString[0],
    GuiParentFromInfo(Self, Info)));
end;

procedure TdwsGuiUnit.DoGuiCreateEdit(Info: TProgramInfo);
begin
  RequireManager;
  SetResultControl(Info, FManager.CreateEdit(Info.ParamAsString[0],
    GuiParentFromInfo(Self, Info)));
end;

procedure TdwsGuiUnit.DoGuiCreateLabel(Info: TProgramInfo);
begin
  RequireManager;
  SetResultControl(Info, FManager.CreateLabel(Info.ParamAsString[0],
    GuiParentFromInfo(Self, Info)));
end;

procedure TdwsGuiUnit.DoGuiCreateAdvancedLabel(Info: TProgramInfo);
begin
  RequireManager;
  SetResultControl(Info, FManager.CreateAdvancedLabel(Info.ParamAsString[0],
    GuiParentFromInfo(Self, Info)));
end;

procedure TdwsGuiUnit.DoGuiCreateWindow(Info: TProgramInfo);
begin
  RequireManager;
  SetResultControl(Info, FManager.CreateWindow(Info.ParamAsString[0],
    GuiParentFromInfo(Self, Info)));
end;

procedure TdwsGuiUnit.DoGuiCreateScrollbar(Info: TProgramInfo);
begin
  RequireManager;
  SetResultControl(Info, FManager.CreateScrollbar(Info.ParamAsString[0],
    GuiParentFromInfo(Self, Info)));
end;

procedure TdwsGuiUnit.DoGuiCreatePopupMenu(Info: TProgramInfo);
begin
  RequireManager;
  SetResultControl(Info, FManager.CreatePopupMenu(Info.ParamAsString[0],
    GuiParentFromInfo(Self, Info)));
end;

procedure TdwsGuiUnit.DoGuiCreateStringGrid(Info: TProgramInfo);
begin
  RequireManager;
  SetResultControl(Info, FManager.CreateStringGrid(Info.ParamAsString[0],
    GuiParentFromInfo(Self, Info)));
end;

procedure TdwsGuiUnit.DoGuiEventControl(Info: TProgramInfo);
begin
  SetResultControl(Info, FEventControl);
end;

procedure TdwsGuiUnit.DoGuiEventName(Info: TProgramInfo);
begin
  Info.ResultAsString := FEventName;
end;

procedure TdwsGuiUnit.DoGuiEventHandlerName(Info: TProgramInfo);
begin
  Info.ResultAsString := FEventHandlerName;
end;

procedure TdwsGuiUnit.DoGuiEventX(Info: TProgramInfo);
begin
  Info.ResultAsFloat := FEventData.X;
end;

procedure TdwsGuiUnit.DoGuiEventY(Info: TProgramInfo);
begin
  Info.ResultAsFloat := FEventData.Y;
end;

procedure TdwsGuiUnit.DoGuiEventValue(Info: TProgramInfo);
begin
  Info.ResultAsFloat := FEventData.Value;
end;

procedure TdwsGuiUnit.DoGuiEventIndex(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FEventData.Index;
end;

procedure TdwsGuiUnit.DoGuiEventButton(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FEventData.Button;
end;

procedure TdwsGuiUnit.DoGuiEventKey(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FEventData.Key;
end;

procedure TdwsGuiUnit.DoGuiEventModifiers(Info: TProgramInfo);
begin
  Info.ResultAsInteger := FEventData.Modifiers;
end;

procedure TdwsGuiUnit.DoGuiEventText(Info: TProgramInfo);
begin
  Info.ResultAsString := FEventData.Text;
end;

constructor TdwsGuiUnit.RegisterGui(AOwner: TComponent;
  AScript: TDelphiWebScript; AManager: TGuiManager);

  procedure RegisterCreateFunction(const AName, AResultType: string;
    AOnEval: TFuncEvalEvent);
  begin
    RegisterGuiFunction(AName, AResultType, ['Name'], ['String'],
      AOnEval, True);
    RegisterGuiFunction(AName, AResultType, ['Name', 'Parent'],
      ['String', 'TGuiControl'], AOnEval, True);
  end;

begin
  inherited Create(AOwner);
  UnitName := 'EngineGui';
  Dependencies.Add('FastMath');
  Script := AScript;
  ImplicitUse := True;
  FManager := AManager;
  FEventData := TGuiEventData.Empty;

  RegisterGuiClasses;

  RegisterGuiFunction('GuiEnabled', 'Boolean', [], [], DoGuiEnabled);
  RegisterGuiFunction('GuiSetEnabled', '', ['Enabled'], ['Boolean'],
    DoGuiSetEnabled);
  RegisterGuiFunction('GuiLoadLayout', 'Boolean', ['FileName'], ['String'],
    DoGuiLoadLayout, True);
  RegisterGuiFunction('GuiLoadLayout', 'Boolean',
    ['FileName', 'TextureFileName'], ['String', 'String'],
    DoGuiLoadLayout, True);
  RegisterGuiFunction('GuiSetTexture', 'Boolean', ['FileName'], ['String'],
    DoGuiSetTexture);
  RegisterGuiFunction('GuiClear', '', [], [], DoGuiClear);
  RegisterGuiFunction('GuiRoot', 'TGuiControl', [], [], DoGuiRoot);
  RegisterGuiFunction('GuiControlCount', 'Integer', [], [], DoGuiControlCount);
  RegisterGuiFunction('GuiControl', 'TGuiControl', ['Index'], ['Integer'],
    DoGuiControl);
  RegisterGuiFunction('GuiFindControl', 'TGuiControl', ['Name'], ['String'],
    DoGuiFindControl);
  RegisterGuiFunction('GuiControlFromHandle', 'TGuiControl', ['Handle'],
    ['Integer'], DoGuiControlFromHandle);
  RegisterGuiFunction('GuiControlHandle', 'Integer', ['Control'],
    ['TGuiControl'], DoGuiControlHandle);

  RegisterCreateFunction('GuiCreatePanel', 'TGuiPanel', DoGuiCreatePanel);
  RegisterCreateFunction('GuiCreateButton', 'TGuiButton', DoGuiCreateButton);
  RegisterCreateFunction('GuiCreateCheckBox', 'TGuiCheckBox',
    DoGuiCreateCheckBox);
  RegisterCreateFunction('GuiCreateEdit', 'TGuiEdit', DoGuiCreateEdit);
  RegisterCreateFunction('GuiCreateLabel', 'TGuiLabel', DoGuiCreateLabel);
  RegisterCreateFunction('GuiCreateAdvancedLabel', 'TGuiAdvancedLabel',
    DoGuiCreateAdvancedLabel);
  RegisterCreateFunction('GuiCreateWindow', 'TGuiWindow', DoGuiCreateWindow);
  RegisterCreateFunction('GuiCreateScrollbar', 'TGuiScrollbar',
    DoGuiCreateScrollbar);
  RegisterCreateFunction('GuiCreatePopupMenu', 'TGuiPopupMenu',
    DoGuiCreatePopupMenu);
  RegisterCreateFunction('GuiCreateStringGrid', 'TGuiStringGrid',
    DoGuiCreateStringGrid);

  RegisterGuiFunction('GuiEventControl', 'TGuiControl', [], [],
    DoGuiEventControl);
  RegisterGuiFunction('GuiEventName', 'String', [], [], DoGuiEventName);
  RegisterGuiFunction('GuiEventHandlerName', 'String', [], [],
    DoGuiEventHandlerName);
  RegisterGuiFunction('GuiEventX', 'Float', [], [], DoGuiEventX);
  RegisterGuiFunction('GuiEventY', 'Float', [], [], DoGuiEventY);
  RegisterGuiFunction('GuiEventValue', 'Float', [], [], DoGuiEventValue);
  RegisterGuiFunction('GuiEventIndex', 'Integer', [], [], DoGuiEventIndex);
  RegisterGuiFunction('GuiEventButton', 'Integer', [], [], DoGuiEventButton);
  RegisterGuiFunction('GuiEventKey', 'Integer', [], [], DoGuiEventKey);
  RegisterGuiFunction('GuiEventModifiers', 'Integer', [], [],
    DoGuiEventModifiers);
  RegisterGuiFunction('GuiEventText', 'String', [], [], DoGuiEventText);
end;

procedure TdwsGuiUnit.BindManager(AManager: TGuiManager);
begin
  FManager := AManager;
  if (FEventControl <> nil) and
     ((FManager = nil) or not FManager.ContainsControl(FEventControl)) then
    EndEvent;
end;

procedure TdwsGuiUnit.BeginEvent(AControl: TGuiControl;
  const AEventName, AHandlerName: string; const AData: TGuiEventData);
begin
  FEventControl := AControl;
  FEventName := AEventName;
  FEventHandlerName := AHandlerName;
  FEventData := AData;
end;

procedure TdwsGuiUnit.EndEvent;
begin
  FEventControl := nil;
  FEventName := '';
  FEventHandlerName := '';
  FEventData := TGuiEventData.Empty;
end;

end.
