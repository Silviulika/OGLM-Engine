unit Editor.AssetBrowser.Models;

interface

type
  TModelFileInfo = record
    FileName: string;
    RelativePath: string;
    DisplayName: string;
    Summary: string;
    FileSize: Int64;
    ModifiedText: string;
    Selected: Boolean;
  end;

  TModelFileBrowserMode = (
    modelBrowserLoadObject,
    modelBrowserLoadWindTree,
    modelBrowserLoadVertexWindTree,
    modelBrowserAddMesh,
    modelBrowserLoadAnimationClips
  );

  TModelFileBrowserState = record
    Active: Boolean;
    Mode: TModelFileBrowserMode;
    CreateAsObject: Boolean;
    CreateWindTree: Boolean;
    CreateVertexWindTree: Boolean;
    AutoPlayFirstAnimation: Boolean;
    NeedsRefresh: Boolean;
    SelectedIndex: Integer;
    Search: array[0..127] of AnsiChar;
    Items: TArray<TModelFileInfo>;
    LastError: string;
  end;

implementation

end.