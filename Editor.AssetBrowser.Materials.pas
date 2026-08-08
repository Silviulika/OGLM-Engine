unit Editor.AssetBrowser.Materials;

interface

uses
  dglOpenGL;

type
  TMaterialFileBrowserMode = (
    mfbNone,
    mfbLoadMaterial,
    mfbSaveMaterial,
    mfbLoadLibrary,
    mfbSaveLibrary
  );

  TMaterialFileInfo = record
    FileName: string;
    RelativePath: string;
    DisplayName: string;
    Summary: string;
    PreviewTexturePath: string;
    IsLibrary: Boolean;
    TextureID: GLuint;
    Width: Integer;
    Height: Integer;
    PreviewReady: Boolean;
  end;

  TMaterialFileBrowserState = record
    Active: Boolean;
    NeedsRefresh: Boolean;
    Mode: TMaterialFileBrowserMode;
    SelectedIndex: Integer;
    PendingOverwrite: Boolean;
    Search: array[0..127] of AnsiChar;
    FileName: array[0..255] of AnsiChar;
    PendingOverwriteFileName: string;
    Items: TArray<TMaterialFileInfo>;
    LastError: string;
  end;

  TMaterialEditorImState = record
    Active: Boolean;
    SelectedLibraryIndex: Integer;
    SelectedMaterialIndex: Integer;
    SelectedTextureIndex: Integer;
    NewLibraryName: array[0..127] of AnsiChar;
    NewMaterialName: array[0..127] of AnsiChar;
    NewMaterialType: Integer;
  end;

implementation

end.