unit Editor.Panels.Scripting;

interface

type
  TScriptEditorOverwriteKind = (
    sowNone,
    sowLibrary,
    sowAsset
  );

  TScriptFileKind = (
    sfkLibrary,
    sfkAsset
  );

  TScriptFileInfo = record
    FileName: string;
    RelativePath: string;
    DisplayName: string;
    Kind: TScriptFileKind;
    FileSize: Int64;
    ModifiedText: string;
  end;

  TScriptEditorState = record
    NeedsFileRefresh: Boolean;
    SelectedFileIndex: Integer;
    SelectedIndex: Integer;
    PendingOverwrite: Boolean;
    PendingOverwriteKind: TScriptEditorOverwriteKind;
    PendingOverwriteFileName: string;
    SourceEditorActive: Boolean;
    SourceEditorHovered: Boolean;
    SourceRectMinX: Single;
    SourceRectMinY: Single;
    SourceRectMaxX: Single;
    SourceRectMaxY: Single;
    Search: array[0..127] of AnsiChar;
    NewScriptName: array[0..127] of AnsiChar;
    Name: array[0..127] of AnsiChar;
    Description: array[0..255] of AnsiChar;
    Author: array[0..127] of AnsiChar;
    Category: array[0..127] of AnsiChar;
    VersionText: array[0..63] of AnsiChar;
    EntryPoint: array[0..127] of AnsiChar;
    TargetName: array[0..255] of AnsiChar;
    LibraryFileName: array[0..255] of AnsiChar;
    AssetFileName: array[0..255] of AnsiChar;
    Source: array[0..65535] of AnsiChar;
    Files: TArray<TScriptFileInfo>;
    Status: string;
    LastError: string;
    Dirty: Boolean;
  end;

implementation

end.