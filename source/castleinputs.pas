{
  Copyright 2006,2007 Michalis Kamburelis.

  This file is part of "castle".

  "castle" is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  "castle" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with "castle"; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}

{ Key/mouse shortcuts of the game. }
unit CastleInputs;

interface

uses Keys, MatrixNavigation, KambiUtils, KambiClassUtils;

{$define read_interface}

type
  TInputGroup = (kgBasic, kgItems, kgOther);

  { This is basically a wrapper around TInputShortcut instance
    (used to describe key/mouse shortcut for given action)
    with additional properties describing the group of the action,
    action name etc. }
  TInputConfiguration = class
  private
    FName: string;
    FGroup: TInputGroup;
    FShortcut: TInputShortcut;
    FConfigFileName: string;
    procedure ShortcutChanged(Shortcut: TInputShortcut);
  public
    { Constructor. Note that TInputShortcut instance passed here is owned
      by this object, i.e. it will be freed in our destructor. }
    constructor Create(const AName: string;
      const AConfigFileName: string;
      const AGroup: TInputGroup;
      AShortcut: TInputShortcut);
    destructor Destroy; override;

    property Name: string read FName;
    property ConfigFileName: string read FConfigFileName;
    property Group: TInputGroup read FGroup;

    { The key/mouse shortcut for this action.
      You can directly change fields of this action,
      but don't mess with it's OnChanged property --- we will use
      it in this class internally. }
    property Shortcut: TInputShortcut read FShortcut;

    { This adds to Shortcut NewKey (if MouseEvent = @false,
      NewKey must be <> K_None in this case) or
      NewMouseButton (if MouseEvent = @true). }
    procedure AddShortcut(const MouseEvent: boolean;
      const NewKey: TKey; const NewMouseButton: TMouseButton);
  end;

  TObjectsListItem_3 = TInputConfiguration;
  {$I objectslist_3.inc}
  TInputConfigurationsList = class(TObjectsList_3)
  public
    { Seeks for a Shortcut that has matching Key (if MouseEvent = @false,
      Key must be <> K_None in this case) or matching MouseButton
      (if MouseEvent = @true).
      @nil if not found. }
    function SeekMatchingShortcut(const MouseEvent: boolean;
      const Key: TKey; const  MouseButton: TMouseButton): TInputConfiguration;
    procedure RestoreDefaults;
    procedure SaveToConfigFile;
    procedure LoadFromConfigFile;

    function SeekConflict(out ConflictDescription: string): boolean;
  end;

  TInputChangedEvent = procedure (InputConfiguration: TInputConfiguration) of object;
  PInputChangedEvent = ^TInputChangedEvent;

  TDynArrayItem_1 = TInputChangedEvent;
  PDynArrayItem_1 = PInputChangedEvent;
  {$define DYNARRAY_1_IS_FUNCTION}
  {$I dynarray_1.inc}
  TDynInputChangedEventArray = class(TDynArray_1)
  public
    procedure ExecuteAll(InputConfiguration: TInputConfiguration);
  end;

var
  { Basic shortcuts. }
  CastleInput_Attack: TInputConfiguration;
  CastleInput_Forward: TInputConfiguration;
  CastleInput_Backward: TInputConfiguration;
  CastleInput_LeftRot: TInputConfiguration;
  CastleInput_RightRot: TInputConfiguration;
  CastleInput_LeftStrafe: TInputConfiguration;
  CastleInput_RightStrafe: TInputConfiguration;
  CastleInput_UpRotate: TInputConfiguration;
  CastleInput_DownRotate: TInputConfiguration;
  CastleInput_HomeUp: TInputConfiguration;
  CastleInput_UpMove: TInputConfiguration;
  CastleInput_DownMove: TInputConfiguration;

  { Items shortcuts. }
  CastleInput_InventoryShow: TInputConfiguration;
  CastleInput_InventoryPrevious: TInputConfiguration;
  CastleInput_InventoryNext: TInputConfiguration;
  CastleInput_UseItem: TInputConfiguration;
  CastleInput_DropItem: TInputConfiguration;

  { Other shortcuts. }
  CastleInput_ViewMessages: TInputConfiguration;
  CastleInput_SaveScreen: TInputConfiguration;
  CastleInput_CancelFlying: TInputConfiguration;
  CastleInput_FPSShow: TInputConfiguration;
  CastleInput_Interact: TInputConfiguration;
  CastleInput_DebugMenu: TInputConfiguration;

  { List of all configurable shortcuts.
    Will be created in initialization and freed in finalization of this unit.
    All TInputConfiguration instances will automatically add to this. }
  CastleAllInputs: TInputConfigurationsList;
  CastleGroupInputs: array[TInputGroup] of TInputConfigurationsList;

  OnInputChanged: TDynInputChangedEventArray;

function InteractInputDescription: string;

{$undef read_interface}

implementation

uses SysUtils, CastleConfig;

{$define read_implementation}
{$I dynarray_1.inc}
{$I objectslist_3.inc}

function InteractInputDescription: string;
begin
  Result := CastleInput_Interact.Shortcut.Description('"Interact" key');
end;

{ TInputConfigurationsList ----------------------------------------------------- }

function TInputConfigurationsList.SeekMatchingShortcut(
  const MouseEvent: boolean;
  const Key: TKey; const  MouseButton: TMouseButton): TInputConfiguration;
var
  I: Integer;
begin
  for I := 0 to High do
  begin
    Result := Items[I];
    if Result.Shortcut.IsEvent(MouseEvent, Key, MouseButton) then
      Exit;
  end;
  Result := nil;
end;

procedure TInputConfigurationsList.RestoreDefaults;
var
  I: Integer;
begin
  for I := 0 to High do
    Items[I].Shortcut.MakeDefault;
end;

procedure TInputConfigurationsList.SaveToConfigFile;
var
  I: Integer;
begin
  for I := 0 to High do
  begin
    ConfigFile.SetDeleteValue('inputs/' + Items[I].ConfigFileName + '/key1',
      Items[I].Shortcut.Key1, Items[I].Shortcut.DefaultKey1);
    ConfigFile.SetDeleteValue('inputs/' + Items[I].ConfigFileName + '/key2',
      Items[I].Shortcut.Key2, Items[I].Shortcut.DefaultKey2);
    ConfigFile.SetDeleteValue('inputs/' + Items[I].ConfigFileName + '/mouse_button_use',
      Items[I].Shortcut.MouseButtonUse, Items[I].Shortcut.DefaultMouseButtonUse);
    ConfigFile.SetDeleteValue('inputs/' + Items[I].ConfigFileName + '/mouse_button',
      Ord(Items[I].Shortcut.MouseButton), Ord(Items[I].Shortcut.DefaultMouseButton));
  end;
end;

procedure TInputConfigurationsList.LoadFromConfigFile;
var
  I: Integer;
begin
  for I := 0 to High do
  begin
    Items[I].Shortcut.Key1 := ConfigFile.GetValue(
      'inputs/' + Items[I].ConfigFileName + '/key1', Items[I].Shortcut.DefaultKey1);
    Items[I].Shortcut.Key2 := ConfigFile.GetValue(
      'inputs/' + Items[I].ConfigFileName + '/key2', Items[I].Shortcut.DefaultKey2);
    Items[I].Shortcut.MouseButtonUse := ConfigFile.GetValue(
      'inputs/' + Items[I].ConfigFileName + '/mouse_button_use',
      Items[I].Shortcut.DefaultMouseButtonUse);
    Items[I].Shortcut.MouseButton := TMouseButton(ConfigFile.GetValue(
      'inputs/' + Items[I].ConfigFileName + '/mouse_button',
      Ord(Items[I].Shortcut.DefaultMouseButton)));
  end;
end;

function TInputConfigurationsList.SeekConflict(
  out ConflictDescription: string): boolean;
var
  I, J: Integer;
begin
  for I := 0 to High do
    for J := I + 1 to High do
    begin
      if Items[J].Shortcut.IsKey(Items[I].Shortcut.Key1) or
         Items[J].Shortcut.IsKey(Items[I].Shortcut.Key2) or
         (Items[I].Shortcut.MouseButtonUse and
           Items[J].Shortcut.IsMouseButton(Items[I].Shortcut.MouseButton)) then
      begin
        ConflictDescription := Format('"%s" conflicts with "%s"',
          [Items[I].Name, Items[J].Name]);
        Exit(true);
      end;
    end;
  Result := false;
end;

{ TDynInputChangedEventArray -------------------------------------------------- }

procedure TDynInputChangedEventArray.ExecuteAll(
  InputConfiguration: TInputConfiguration);
var
  I: Integer;
begin
  for I := 0 to High do
    Items[I](InputConfiguration);
end;

{ TInputConfiguration ---------------------------------------------------------- }

constructor TInputConfiguration.Create(const AName: string;
  const AConfigFileName: string;
  const AGroup: TInputGroup;
  AShortcut: TInputShortcut);
begin
  inherited Create;
  FName := AName;
  FConfigFileName := AConfigFileName;
  FGroup := AGroup;

  FShortcut := AShortcut;
  FShortcut.OnChanged := @ShortcutChanged;

  CastleAllInputs.Add(Self);
  CastleGroupInputs[Group].Add(Self);
end;

destructor TInputConfiguration.Destroy;
begin
  FreeAndNil(FShortcut);
  inherited;
end;

procedure TInputConfiguration.ShortcutChanged(Shortcut: TInputShortcut);
begin
  Assert(Shortcut = Self.Shortcut);
  OnInputChanged.ExecuteAll(Self);
end;

procedure TInputConfiguration.AddShortcut(const MouseEvent: boolean;
  const NewKey: TKey; const NewMouseButton: TMouseButton);
begin
  if MouseEvent then
  begin
    Shortcut.MouseButtonUse := true;
    Shortcut.MouseButton := NewMouseButton;
  end else
  if Shortcut.Key1 = K_None then
    Shortcut.Key1 := NewKey else
  if Shortcut.Key2 = K_None then
    Shortcut.Key2 := NewKey else
  begin
    { We move the previous Key1 to Key2, and set Key1 to new key.
      This looks nice for user when Shortcut is displayed as the
      menu argument. }
    Shortcut.Key2 := Shortcut.Key1;
    Shortcut.Key1 := NewKey;
  end;
end;

{ initialization / finalization ---------------------------------------------- }

procedure DoInitialization;
var
  InputGroup: TInputGroup;
  ConflictDescription: string;
begin
  OnInputChanged := TDynInputChangedEventArray.Create;
  CastleAllInputs := TInputConfigurationsList.Create;

  for InputGroup := Low(InputGroup) to High(InputGroup) do
    CastleGroupInputs[InputGroup] := TInputConfigurationsList.Create;

  { Order of creation below is significant: it determines the order
    of menu entries in "Configure controls". }

  { Basic shortcuts. }
  CastleInput_Attack := TInputConfiguration.Create('Attack', 'attack', kgBasic,
    TInputShortcut.Create(K_Ctrl, K_None, true, mbLeft));
  CastleInput_Forward := TInputConfiguration.Create('Move forward', 'move_forward', kgBasic,
    TInputShortcut.Create(K_W, K_Up, false, mbLeft));
  CastleInput_Backward := TInputConfiguration.Create('Move backward', 'move_backward', kgBasic,
    TInputShortcut.Create(K_S, K_Down, false, mbLeft));
  CastleInput_LeftStrafe := TInputConfiguration.Create('Move left', 'move_left', kgBasic,
    TInputShortcut.Create(K_A, K_None, false, mbLeft));
  CastleInput_RightStrafe := TInputConfiguration.Create('Move right', 'move_right', kgBasic,
    TInputShortcut.Create(K_D, K_None, false, mbLeft));
  CastleInput_LeftRot := TInputConfiguration.Create('Turn left', 'turn_left', kgBasic,
    TInputShortcut.Create(K_Left, K_None, false, mbLeft));
  CastleInput_RightRot := TInputConfiguration.Create('Turn right', 'turn_right', kgBasic,
    TInputShortcut.Create(K_Right, K_None, false, mbLeft));
  CastleInput_UpRotate := TInputConfiguration.Create('Look up', 'look_up', kgBasic,
    TInputShortcut.Create(K_PageDown, K_None, false, mbLeft));
  CastleInput_DownRotate := TInputConfiguration.Create('Look down', 'look_down', kgBasic,
    TInputShortcut.Create(K_Delete, K_None, false, mbLeft));
  CastleInput_HomeUp := TInputConfiguration.Create('Look straight', 'look_straight', kgBasic,
    TInputShortcut.Create(K_End, K_None, false, mbLeft));
  CastleInput_UpMove := TInputConfiguration.Create('Jump (or fly/swim up)', 'move_up', kgBasic,
    TInputShortcut.Create(K_Space, K_None, true, mbRight));
  CastleInput_DownMove := TInputConfiguration.Create('Crouch (or fly/swim down)', 'move_down', kgBasic,
    TInputShortcut.Create(K_C, K_None, false, mbLeft));

  { Items shortcuts. }
  CastleInput_InventoryShow := TInputConfiguration.Create('Inventory show / hide', 'inventory_toggle', kgItems,
    TInputShortcut.Create(K_I, K_None, false, mbLeft));
  CastleInput_InventoryPrevious := TInputConfiguration.Create('Select previous inventory item', 'inventory_previous', kgItems,
    TInputShortcut.Create(K_LeftBracket, K_None, false, mbLeft));
  CastleInput_InventoryNext := TInputConfiguration.Create('Select next inventory item', 'inventory_next', kgItems,
    TInputShortcut.Create(K_RightBracket, K_None, false, mbLeft));
  CastleInput_UseItem := TInputConfiguration.Create('Use (or equip) selected inventory item', 'item_use', kgItems,
    TInputShortcut.Create(K_Enter, K_None, false, mbLeft));
  CastleInput_DropItem := TInputConfiguration.Create('Drop selected inventory item', 'item_drop', kgItems,
    TInputShortcut.Create(K_R, K_None, false, mbLeft));

  { Other shortcuts. }
  CastleInput_ViewMessages := TInputConfiguration.Create('View all messages', 'view_messages', kgOther,
    TInputShortcut.Create(K_M, K_None, false, mbLeft));
  CastleInput_SaveScreen := TInputConfiguration.Create('Save screen', 'save_screen', kgOther,
    TInputShortcut.Create(K_F5, K_None, false, mbLeft));
  CastleInput_CancelFlying := TInputConfiguration.Create('Cancel flying spell', 'cancel_flying', kgOther,
    TInputShortcut.Create(K_Q, K_None, false, mbLeft));
  CastleInput_FPSShow := TInputConfiguration.Create('FPS show / hide', 'fps_toggle', kgOther,
    TInputShortcut.Create(K_Tab, K_None, false, mbLeft));
  CastleInput_Interact := TInputConfiguration.Create('Interact (press button / open door etc.)', 'interact', kgOther,
    TInputShortcut.Create(K_E, K_None, false, mbLeft));
  CastleInput_DebugMenu := TInputConfiguration.Create('Debug menu', 'debug_menu', kgOther,
    TInputShortcut.Create(K_BackQuote, K_None, false, mbLeft));

  if CastleAllInputs.SeekConflict(ConflictDescription) then
    raise EInternalError.Create(
      'Default key/mouse shortcuts layout has conflicts: ' + ConflictDescription);

  CastleAllInputs.LoadFromConfigFile;

  if CastleAllInputs.SeekConflict(ConflictDescription) then
  begin
    WarningWrite(
      'Your key/mouse shortcuts layout has conflicts. This can happen if you ' +
      'just upgraded the game to newer version, and the newer version has new ' +
      'key/mouse shortcuts or has different default key/mouse shortcuts than previous ' +
      'version. It can also happen if you manually edited the configuration ' +
      'file. I will reset your key/mouse shortcuts to default now.' +nl+
      nl+
      'Detailed conflict description: ' + ConflictDescription);
    CastleAllInputs.RestoreDefaults;
  end;
end;

procedure DoFinalization;
var
  InputGroup: TInputGroup;
begin
  CastleAllInputs.SaveToConfigFile;

  for InputGroup := Low(InputGroup) to High(InputGroup) do
    FreeAndNil(CastleGroupInputs[InputGroup]);

  FreeWithContentsAndNil(CastleAllInputs);
  FreeAndNil(OnInputChanged);
end;

initialization
  DoInitialization;
finalization
  DoFinalization;
end.