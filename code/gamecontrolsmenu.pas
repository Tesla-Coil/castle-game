{
  Copyright 2006-2017 Michalis Kamburelis.

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
  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA

  ----------------------------------------------------------------------------
}

{ }
unit GameControlsMenu;

interface

uses Classes, CastleWindow, GameGeneralMenu, CastleCameras,
  CastleFonts, CastleUIControls, CastlePlayer, CastleUIState,
  CastleKeysMouse;

type
  TSubMenu = class(TCastleGameMenu)
  public
    SubMenuTitle: string;
    { Note that you can freely change this at runtime. }
    SubMenuAdditionalInfo: string;
    constructor Create(AOwner: TComponent); override;
    procedure Render; override;
  end;

  { Show menu that allows player to configure controls. }
  TStateControlsMenu = class(TAbstractMenuState)
  strict private
    type
      TFadeRect = class(TUIControl)
        procedure Render; override;
      end;
    var
    FadeRect: TFadeRect;
  public
    { User can quit with the escape key. }
    ExitWithEscapeAllowed: boolean;
    { If ExitWithEscapeAllowed, this will be set to @true or @false,
      depending on whether user used escape to exit. }
    ExitWithEscape: boolean;
    DrawFadeRect, DrawCentered: boolean;
    constructor Create(AOwner: TComponent); override;
    procedure Start; override;
    procedure Stop; override;
   function Press(const Event: TInputPressRelease): boolean; override;
  end;

var
  StateControlsMenu: TStateControlsMenu;

var
  { Font used for menu SubMenuTitle.
    Initialized / finalized here. }
  SubMenuTitleFont: TCastleFont;

var
  UseTouchInterface: boolean =
    {$ifdef ANDROID} true {$else}
    {$ifdef IOS}     true {$else}
                     false {$endif}
                           {$endif};

{ Update MouseLook-related player settings, based on what is chosen
  in "Confgure controls" menu. }
procedure PlayerUpdateMouseLook(Player: TPlayer);

implementation

uses SysUtils, CastleGLUtils, CastleMessages,
  CastleOnScreenMenu, CastleConfig,
  CastleInputs, CastleVectors, CastleUtils, CastleRectangles,
  CastleStringUtils, CastleGameNotifications, GameWindow, CastleColors,
  CastleControls, CastleTextureFont_DejaVuSansMono_18,
  CastleApplicationProperties;

const
  DefaultMouseLook = true;
  DefaultInvertVerticalMouseLook = false;

var
  { Game player camera settings.
    Automatically saved/loaded from user preferences using CastleConfig.
    @groupBegin }
  MouseLook: boolean = DefaultMouseLook;
  InvertVerticalMouseLook: boolean = DefaultInvertVerticalMouseLook;
  MouseLookHorizontalSensitivity: Single;
  MouseLookVerticalSensitivity: Single;
  { @groupEnd }

procedure PlayerUpdateMouseLook(Player: TPlayer);
begin
  Player.Camera.MouseLookHorizontalSensitivity := MouseLookHorizontalSensitivity;
  Player.Camera.MouseLookVerticalSensitivity := MouseLookVerticalSensitivity;
  Player.Camera.InvertVerticalMouseLook := InvertVerticalMouseLook;
  { MouseLook is allowed always, even when player is dead.
    Just like rotation keys.
    Note that when Blocked, rotating will actually
    be disabled by Input := []. But still mouse look will cause mouse
    to remain hidden, which is good (why pop the mouse cursor on game
    win animation?). }
  Player.Camera.MouseLook := MouseLook and not UseTouchInterface;
end;

{ TCastleGameMenu descendants interface ------------------------------------------ }

type
  TControlsMenu = class(TSubMenu)
  strict private
    procedure ClickBasicControls(Sender: TObject);
    procedure ClickItemsControls(Sender: TObject);
    procedure ClickOtherControls(Sender: TObject);
    procedure ClickMouseLook(Sender: TObject);
    procedure ClickInvertVerticalMouseLook(Sender: TObject);
    procedure ClickAutoOpenInventory(Sender: TObject);
    procedure ClickRestoreDefaults(Sender: TObject);
    procedure ClickBack(Sender: TObject);
    procedure MouseLookHorizontalSensitivityChanged(Sender: TObject);
    procedure MouseLookVerticalSensitivityChanged(Sender: TObject);
  public
    MouseLookHorizontalSensitivitySlider: TCastleFloatSlider;
    MouseLookVerticalSensitivitySlider: TCastleFloatSlider;
    AutoOpenInventoryToggle: TCastleMenuToggle;
    MouseLookToggle: TCastleMenuToggle;
    InvertVerticalMouseLookToggle: TCastleMenuToggle;
    constructor Create(AOwner: TComponent); override;
  end;

  TControlsSubMenu = class(TSubMenu)
  strict private
    FGroup: TInputGroup;
    procedure ClickBack(Sender: TObject);
  private
    { Refresh shortcuts descriptions displayed in the menu
      from current values of CastleInput_Xxx variables. }
    procedure RefreshShortcuts;
  public
    constructor CreateControlsSubMenu(AOwner: TComponent; AGroup: TInputGroup);
    property Group: TInputGroup read FGroup;
  end;

  TBasicControlsMenu = class(TControlsSubMenu)
    constructor Create(AOwner: TComponent); override;
  end;

  TItemsControlsMenu = class(TControlsSubMenu)
    constructor Create(AOwner: TComponent); override;
  end;

  TOtherControlsMenu = class(TControlsSubMenu)
    constructor Create(AOwner: TComponent); override;
  end;

{ ----------------------------------------------------------------------------
  global vars (used by TCastleGameMenu descendants implementation) }

var
  ControlsMenu: TControlsMenu;
  BasicControlsMenu: TBasicControlsMenu;
  ItemsControlsMenu: TItemsControlsMenu;
  OtherControlsMenu: TOtherControlsMenu;

{ TSubMenu ------------------------------------------------------------- }

constructor TSubMenu.Create(AOwner: TComponent);
begin
  inherited;
  SetPosition(false);
  DrawBackgroundRectangle := false;
end;

procedure TSubMenu.Render;
const
  SubMenuTextColor: TCastleColor = (Data: (0.9, 0.9, 0.9, 1.0));
var
  R: TRectangle;
begin
  inherited;

  R := ScreenRect;
  SubMenuTitleFont.Print(R.Left, R.Top - 20,
    SubMenuTextColor, SubMenuTitle + ' :');

  if SubMenuAdditionalInfo <> '' then
    SubMenuTitleFont.PrintBrokenString(
      R.Left,
      R.Bottom - SubMenuTitleFont.RowHeight, SubMenuTextColor,
      SubMenuAdditionalInfo,
      Window.Width - 2 * Round(R.Left), true, 0);
end;

{ TControlsMenu ------------------------------------------------------------- }

constructor TControlsMenu.Create(AOwner: TComponent);
begin
  inherited;

  MouseLookHorizontalSensitivitySlider := TCastleFloatSlider.Create(Self);
  MouseLookHorizontalSensitivitySlider.Min := 0.01;
  MouseLookHorizontalSensitivitySlider.Max := 0.3;
  MouseLookHorizontalSensitivitySlider.Value := MouseLookHorizontalSensitivity;
  MouseLookHorizontalSensitivitySlider.OnChange := @MouseLookHorizontalSensitivityChanged;

  MouseLookVerticalSensitivitySlider := TCastleFloatSlider.Create(Self);
  MouseLookVerticalSensitivitySlider.Min := 0.01;
  MouseLookVerticalSensitivitySlider.Max := 0.3;
  MouseLookVerticalSensitivitySlider.Value := MouseLookVerticalSensitivity;
  MouseLookVerticalSensitivitySlider.OnChange := @MouseLookVerticalSensitivityChanged;

  MouseLookToggle := TCastleMenuToggle.Create(Self);
  MouseLookToggle.Pressed := MouseLook;
  MouseLookToggle.OnClick := @ClickMouseLook;

  InvertVerticalMouseLookToggle := TCastleMenuToggle.Create(Self);
  InvertVerticalMouseLookToggle.Pressed := InvertVerticalMouseLook;
  InvertVerticalMouseLookToggle.OnClick := @ClickInvertVerticalMouseLook;

  AutoOpenInventoryToggle := TCastleMenuToggle.Create(Self);
  AutoOpenInventoryToggle.Pressed := AutoOpenInventory;
  AutoOpenInventoryToggle.OnClick := @ClickAutoOpenInventory;

  Add('Customize basic controls', @ClickBasicControls);
  Add('Customize items controls', @ClickItemsControls);
  Add('Customize other controls', @ClickOtherControls);
  Add('Use mouse look', MouseLookToggle);
  Add('Mouse look horizontal sensitivity', MouseLookHorizontalSensitivitySlider);
  Add('Mouse look vertical sensitivity', MouseLookVerticalSensitivitySlider);
  Add('Invert vertical mouse look', InvertVerticalMouseLookToggle);
  Add('Auto show inventory on pickup', AutoOpenInventoryToggle);
  Add('Restore to defaults', @ClickRestoreDefaults);
  Add('Back to main menu', @ClickBack);

  SubMenuTitle := 'Configure controls';
end;

procedure TControlsMenu.ClickBasicControls(Sender: TObject);
begin
  BasicControlsMenu.RefreshShortcuts;
  StateControlsMenu.CurrentMenu := BasicControlsMenu;
end;

procedure TControlsMenu.ClickItemsControls(Sender: TObject);
begin
  ItemsControlsMenu.RefreshShortcuts;
  StateControlsMenu.CurrentMenu := ItemsControlsMenu;
end;

procedure TControlsMenu.ClickOtherControls(Sender: TObject);
begin
  OtherControlsMenu.RefreshShortcuts;
  StateControlsMenu.CurrentMenu := OtherControlsMenu;
end;

procedure TControlsMenu.ClickMouseLook(Sender: TObject);
begin
  MouseLook := not MouseLook;
  MouseLookToggle.Pressed := MouseLook;
end;

procedure TControlsMenu.ClickInvertVerticalMouseLook(Sender: TObject);
begin
  InvertVerticalMouseLook := not InvertVerticalMouseLook;
  InvertVerticalMouseLookToggle.Pressed := InvertVerticalMouseLook;
end;

procedure TControlsMenu.ClickAutoOpenInventory(Sender: TObject);
begin
  AutoOpenInventory := not AutoOpenInventory;
  AutoOpenInventoryToggle.Pressed := AutoOpenInventory;
end;

procedure TControlsMenu.ClickRestoreDefaults(Sender: TObject);
begin
  InputsAll.RestoreDefaults;

  MouseLook := DefaultMouseLook;
  MouseLookToggle.Pressed := MouseLook;

  InvertVerticalMouseLook := DefaultInvertVerticalMouseLook;
  InvertVerticalMouseLookToggle.Pressed := InvertVerticalMouseLook;

  MouseLookHorizontalSensitivity := TWalkCamera.DefaultMouseLookHorizontalSensitivity;
  MouseLookVerticalSensitivity   := TWalkCamera.DefaultMouseLookVerticalSensitivity  ;
  MouseLookHorizontalSensitivitySlider.Value := MouseLookHorizontalSensitivity;
  MouseLookVerticalSensitivitySlider  .Value := MouseLookVerticalSensitivity  ;

  AutoOpenInventory := DefaultAutoOpenInventory;
  AutoOpenInventoryToggle.Pressed := AutoOpenInventory;

  MessageOK(Window, 'All keys and settings restored to defaults.');
end;

procedure TControlsMenu.ClickBack(Sender: TObject);
begin
  TUIState.Pop(StateControlsMenu);
end;

procedure TControlsMenu.MouseLookHorizontalSensitivityChanged(Sender: TObject);
begin
  MouseLookHorizontalSensitivity := MouseLookHorizontalSensitivitySlider.Value;
end;

procedure TControlsMenu.MouseLookVerticalSensitivityChanged(Sender: TObject);
begin
  MouseLookVerticalSensitivity := MouseLookVerticalSensitivitySlider.Value;
end;

{ TCustomizeInputMenuButton -------------------------------------------------------- }

type
  { Button inside a menu to customize input shortcut. }
  TCustomizeInputMenuButton = class(TCastleMenuButton)
  strict private
    FInputShortcut: TInputShortcut;
    procedure SetInputShortcut(const Value: TInputShortcut);
  public
    property InputShortcut: TInputShortcut read FInputShortcut write SetInputShortcut;
    procedure DoClick; override;
    { Call when InputShortcut value inside was changed. }
    procedure Refresh;
  end;

procedure TCustomizeInputMenuButton.SetInputShortcut(const Value: TInputShortcut);
begin
  if FInputShortcut <> Value then
  begin
    FInputShortcut := Value;
    Refresh;
  end;
end;

procedure TCustomizeInputMenuButton.Refresh;
const
  EmptyInputShortcut = '<not assigned>';
begin
  if InputShortcut <> nil then
    Caption := InputShortcut.Description(EmptyInputShortcut)
  else
    // when InputShortcut not set, we don't have anything to show
    Caption := EmptyInputShortcut;
end;

procedure TCustomizeInputMenuButton.DoClick;
var
  ConflictingInput: TInputShortcut;
  NewEvent: TInputPressRelease;
begin
  inherited;

  NewEvent := MessageKeyMouse(Window, Format(
    'Press the new key or mouse button or mouse wheel for "%s".' + NL + NL +
    '[Escape] cancels.' + NL +
    '[Backspace] clears the shortcut.',
    [InputShortcut.Caption]));

  if NewEvent.IsKey(K_Backspace) then
  begin
    InputShortcut.MakeClear;
  end else
  if NewEvent.IsKey(K_Escape) then
  begin
    { Don't do anything. }
  end else
  { We silently ignore situation when NewEvent already
    matches InputShortcut. This is meaningless,
    and otherwise could unnecessarily swap Key1 and Key2 in InputShortcut. }
  if not InputShortcut.IsEvent(NewEvent) then
  begin
    ConflictingInput := InputsAll.SeekMatchingShortcut(NewEvent);

    if ConflictingInput <> nil then
    begin
      { I used to have here a confirmation before clearing ConflictingInput.
        But this was bad for user experience, as the message would have
        to be either about "clearing the whole shortcut" or just
        "clearing part of the shortcut" --- as each shortcut is
        2 key shortcuts and 1 mouse shortcut.
        Also, one of the rules is to avoid modal dialog boxes...
        So now I just uncoditionally remove conflicting key,
        and make a Notification informing user about it. }
      case NewEvent.EventType of
        itMouseButton:
          begin
            Notifications.Show(Format('Note: "%s" mouse shortcut cleared for action "%s"',
              [ MouseButtonStr[ConflictingInput.MouseButton],
                ConflictingInput.Caption ]));
            ConflictingInput.MouseButtonUse := false;
          end;
        itMouseWheel:
          begin
            Notifications.Show(Format('Note: "%s" mouse wheel cleared for action "%s"',
              [ MouseWheelDirectionStr[ConflictingInput.MouseWheel],
                ConflictingInput.Caption ]));
            ConflictingInput.MouseWheel := mwNone;
          end;
        itKey:
          if ConflictingInput.Key1 = NewEvent.Key then
          begin
            Notifications.Show(Format('Note: "%s" key shortcut cleared for action "%s"',
              [ KeyToStr(ConflictingInput.Key1),
                ConflictingInput.Caption ]));
            ConflictingInput.Key1 := K_None;
          end else
          begin
            Assert(ConflictingInput.Key2 = NewEvent.Key);

            Notifications.Show(Format('Note: "%s" key shortcut cleared for action "%s"',
              [ KeyToStr(ConflictingInput.Key2),
                ConflictingInput.Caption ]));
            ConflictingInput.Key2 := K_None;
          end;
        else raise EInternalError.Create('ConflictingInput: NewEvent.EventType?');
      end;
    end;

    InputShortcut.Add(NewEvent);
  end;

  { possibly, not only this shortcut, but also others changed now }
  (Owner as TControlsSubMenu).RefreshShortcuts;
end;

{ TControlsSubMenu ----------------------------------------------------------- }

constructor TControlsSubMenu.CreateControlsSubMenu(AOwner: TComponent;
  AGroup: TInputGroup);
var
  I: Integer;
  InputShortcut: TInputShortcut;
  InputMenuButton: TCustomizeInputMenuButton;
begin
  inherited Create(AOwner);

  FGroup := AGroup;

  for I := 0 to InputsGroup[Group].Count - 1 do
  begin
    InputShortcut := InputsGroup[Group].Items[I];
    InputMenuButton := TCustomizeInputMenuButton.Create(Self);
    InputMenuButton.InputShortcut := InputShortcut;
    Add(InputShortcut.Caption, InputMenuButton);
  end;

  Add('Back to controls menu', @ClickBack);

  RegularSpaceBetweenItems := 2;
end;

procedure TControlsSubMenu.ClickBack(Sender: TObject);
begin
  StateControlsMenu.CurrentMenu := ControlsMenu;
end;

procedure TControlsSubMenu.RefreshShortcuts;
var
  I: Integer;
begin
  for I := 0 to InputsGroup[Group].Count - 1 do
  begin
    (Controls[I].Controls[0] as TCustomizeInputMenuButton).Refresh;
    { text changed, maybe stuff should be wider / narrower now }
    RecalculateSize;
  end;
end;

{ TBasicControlsMenu ------------------------------------------------------------- }

constructor TBasicControlsMenu.Create(AOwner: TComponent);
begin
  inherited CreateControlsSubMenu(AOwner, igBasic);

  SubMenuTitle := 'Configure basic controls';
end;

{ TItemsControlsMenu --------------------------------------------------------- }

constructor TItemsControlsMenu.Create(AOwner: TComponent);
begin
  inherited CreateControlsSubMenu(AOwner, igItems);

  SubMenuTitle := 'Configure items controls';

  SubMenuAdditionalInfo :=
    'Notes:' +nl+
    '- You pick items lying on the ground just by walking on them.' +nl+
    '- Items are automatically unequipped when you drop them.';
end;

{ TOtherControlsMenu ------------------------------------------------------------- }

constructor TOtherControlsMenu.Create(AOwner: TComponent);
begin
  inherited CreateControlsSubMenu(AOwner, igOther);

  SubMenuTitle := 'Configure other controls';

  SubMenuAdditionalInfo :=
    'Escape key:' +nl+
    '  This can be used in game to exit to game menu.' +nl+
    '  In many other cases it can be used to "exit".' +nl+
    '  This key is not configurable.';

    { Too much info, not needed, I think that player can figure this out:
    nl+
    'Note that the "Cancel flying" key is useful if you want to stop flying ' +
    'before flying spell will automatically wear off.'; }
end;

{ TFadeRect ------------------------------------------------------------------ }

procedure TStateControlsMenu.TFadeRect.Render;
var
  Menu: TCastleGameMenu;
begin
  inherited;
  Menu := (Owner as TStateControlsMenu).CurrentMenu;
  DrawRectangle(Menu.ScreenRect.Grow(150),
    Vector4(0, 0, 0, Menu.BackgroundOpacityFocused));
end;

{ TStateControlsMenu --------------------------------------------------------- }

constructor TStateControlsMenu.Create(AOwner: TComponent);
begin
  inherited;

  ControlsMenu := TControlsMenu.Create(Application);
  BasicControlsMenu := TBasicControlsMenu.Create(Application);
  ItemsControlsMenu := TItemsControlsMenu.Create(Application);
  OtherControlsMenu := TOtherControlsMenu.Create(Application);

  Theme.MessageFont := TTextureFont.Create(TextureFont_DejaVuSansMono_18);
  SubMenuTitleFont := Theme.MessageFont;
end;

function TStateControlsMenu.Press(const Event: TInputPressRelease): boolean;
begin
  Result := inherited;
  if Result then Exit;

  if ExitWithEscapeAllowed and Event.IsKey(CharEscape) then
  begin
    ExitWithEscape := true;
    TUIState.Pop(StateControlsMenu);
  end;
end;

procedure TStateControlsMenu.Start;
begin
  inherited;

  ExitWithEscape := false;

  ControlsMenu     .SetPosition(DrawCentered);
  BasicControlsMenu.SetPosition(DrawCentered);
  ItemsControlsMenu.SetPosition(DrawCentered);
  OtherControlsMenu.SetPosition(DrawCentered);

  CurrentMenu := ControlsMenu;

  if DrawFadeRect then
  begin
    FadeRect := TFadeRect.Create(Self);
    InsertBack(FadeRect);
  end;
end;

procedure TStateControlsMenu.Stop;
begin
  FreeAndNil(FadeRect);
  CurrentMenu := nil;
  inherited;
end;

{ TConfigOptions ------------------------------------------------------------- }

type
  TConfigOptions = class
    class procedure LoadFromConfig(const Config: TCastleConfig);
    class procedure SaveToConfig(const Config: TCastleConfig);
  end;

class procedure TConfigOptions.LoadFromConfig(const Config: TCastleConfig);
begin
  MouseLookHorizontalSensitivity := Config.GetFloat(
    'mouse/horizontal_sensitivity', TWalkCamera.DefaultMouseLookHorizontalSensitivity);
  MouseLookVerticalSensitivity := Config.GetFloat(
    'mouse/vertical_sensitivity', TWalkCamera.DefaultMouseLookVerticalSensitivity);
  MouseLook := Config.GetValue(
    'mouse/use_mouse_look', DefaultMouseLook);
  InvertVerticalMouseLook := Config.GetValue(
    'mouse/invert_vertical_mouse_look', DefaultInvertVerticalMouseLook);
end;

class procedure TConfigOptions.SaveToConfig(const Config: TCastleConfig);
begin
  Config.SetDeleteFloat('mouse/horizontal_sensitivity',
    MouseLookHorizontalSensitivity, TWalkCamera.DefaultMouseLookHorizontalSensitivity);
  Config.SetDeleteFloat('mouse/vertical_sensitivity',
    MouseLookVerticalSensitivity, TWalkCamera.DefaultMouseLookVerticalSensitivity);
  Config.SetDeleteValue('mouse/use_mouse_look',
    MouseLook, DefaultMouseLook);
  Config.SetDeleteValue('mouse/invert_vertical_mouse_look',
    InvertVerticalMouseLook, DefaultInvertVerticalMouseLook);
end;

initialization
  UserConfig.AddLoadListener(@TConfigOptions(nil).LoadFromConfig);
  UserConfig.AddSaveListener(@TConfigOptions(nil).SaveToConfig);
end.
