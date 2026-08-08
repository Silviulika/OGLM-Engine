unit Editor.Panels.SceneTree;

interface

type
  TSceneFileBrowserMode = (
    sfbNone,
    sfbLoadScene,
    sfbSaveScene
  );

  TSceneFileInfo = record
    FileName: string;
    RelativePath: string;
    DisplayName: string;
    SceneName: string;
    Summary: string;
    FileSize: Int64;
    ModifiedText: string;
    ValidScene: Boolean;
  end;

  TSceneFileBrowserState = record
    Active: Boolean;
    NeedsRefresh: Boolean;
    Mode: TSceneFileBrowserMode;
    SelectedIndex: Integer;
    PendingOverwrite: Boolean;
    Search: array[0..127] of AnsiChar;
    FileName: array[0..255] of AnsiChar;
    PendingOverwriteFileName: string;
    Items: TArray<TSceneFileInfo>;
    LastError: string;
  end;

  TPrefabFileBrowserMode = (
    prefabNone,
    prefabSave,
    prefabLoad
  );

  TPrefabFileInfo = record
    FileName: string;
    RelativePath: string;
    DisplayName: string;
    FileSize: Int64;
    ModifiedText: string;
  end;

  TPrefabFileBrowserState = record
    Active: Boolean;
    Mode: TPrefabFileBrowserMode;
    NeedsRefresh: Boolean;
    SelectedIndex: Integer;
    PendingOverwrite: Boolean;
    PendingOverwriteFileName: string;
    Search: array[0..127] of AnsiChar;
    FileName: array[0..255] of AnsiChar;
    Items: TArray<TPrefabFileInfo>;
    LastError: string;
  end;

implementation

end.