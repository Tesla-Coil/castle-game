{
  Copyright 2006-2014 Michalis Kamburelis.

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

  ----------------------------------------------------------------------------
}

{ Playing the game. }

unit GamePlay;

interface

uses Classes, CastleLevels, CastlePlayer, Castle3D, CastleControlsImages,
  CastleRectangles;

{ Play the game.
  SceneManager and Player global variables must be already initialized.
  If PrepareNewPlayer then it will call SceneManager.Logic.PrepareNewPlayer
  right before starting the actual game. }
procedure PlayGame(PrepareNewPlayer: boolean);

type
  TCastle1SceneManager = class(TGameSceneManager)
  protected
    function PointingDeviceActivate3D(const Item: T3D; const Active: boolean;
      const Distance: Single): boolean; override;
  end;

var
  { Currently used player by PlayGame. nil if PlayGame doesn't work
    right now.
    @noAutoLinkHere }
  Player: TPlayer;

  { Currently used scene manager by PlayGame. nil if PlayGame doesn't work
    right now.
    @noAutoLinkHere }
  SceneManager: TCastle1SceneManager;

{ Load new level or (if NextLevelName is empty) end the game.

  Loading of new level doesn't happen immediately, as it could interfere
  with various other operations. Instead, this procedure merely records
  the need to do it, and actual work will be done later at good code place. }
procedure LevelFinished(NextLevelName: string);

{ If some LevelFinished call is scheduled, this will force changing
  level @italic(now). Don't use this, unless you know that you can
  safely change the level now (which means that old level will be
  destroyed, along with all it's items, creatures etc. references). }
procedure LevelFinishedFlush;

var
  { Read-only from outside of this unit. }
  GameEnded: boolean;
  { Will be a level name (<> '') if user wants to immediately restart the game.
    This is important only if GameEnded.
    Caller of PlayGame should use this. }
  GameEndedWantsRestart: string;

  { Read-only from outside of this unit. Initially false when starting
    PlayGame. }
  GameWin: boolean;

{ Note that when Player.Dead or GameWin,
  confirmation will never be required anyway. }
procedure GameCancel(RequireConfirmation: boolean);

var
  DebugRenderForLevelScreenshot: boolean = false;

implementation

uses SysUtils, CastleUtils, CastleWindow, GameInputs,
  CastleWindowModes, CastleGLUtils, CastleMessages, GameWindow,
  CastleVectors, CastleImages, Math, GameHelp, CastleUIControls, CastleSoundEngine,
  GameItems, CastleStringUtils, CastleCreatures, CastleItems,
  CastleFilesUtils, CastleInputs, GameGameMenu, GameDebugMenu, GameSound,
  GameVideoOptions, CastleColors, CastleSceneManager,
  CastleGameNotifications, GameControlsMenu, CastleControls,
  GameLevelSpecific, CastleTimeUtils, CastleGLImages, CastleKeysMouse;

var
  GLNotificationsFade: TGLImage;
  GLInventorySlot: TGLImage;
  GLBlankIndicatorImage: TGLImage;
  GLRedIndicatorImage: TGLImage;
  GLBlueIndicatorImage: TGLImage;
  GLBossIndicatorImage: TGLImage;

  DisplayFpsUpdateTick: TMilisecTime;
  DisplayFpsFrameTime: Single;
  DisplayFpsRealTime: Single;

  ShowDebugInfo: boolean;

  LevelFinishedSchedule: boolean = false;
  { If LevelFinishedSchedule, then this is not-'', and should be the name
    of next Level to load. }
  LevelFinishedNextLevelName: string;

  GameControls: TUIControlList;

{ TGame2DControls ------------------------------------------------------------ }

type
  TGame2DControls = class(TUIControl)
  public
    procedure Render; override;
  end;

procedure TGame2DControls.Render;

  procedure DoRenderInventory;
  const
    InventorySlotWidth = 100;
    InventorySlotHeight = 100;
    InventorySlotMargin = 2;
  var
    InventorySlotsVisibleInColumn: Integer;

    function ItemSlotX(I: Integer): Integer;
    begin
      Result := Window.Width - InventorySlotWidth *
        ((I div InventorySlotsVisibleInColumn) + 1);
    end;

    function ItemSlotY(I: Integer): Integer;
    begin
      Result := InventorySlotHeight * (InventorySlotsVisibleInColumn
        - 1 - (I mod InventorySlotsVisibleInColumn));
    end;

  const
    NameColor: TCastleColor = (1.0, 1.0, 0.5, 1.0);
  var
    I, X, Y: Integer;
    S: string;
  begin
    InventorySlotsVisibleInColumn := ContainerHeight div InventorySlotHeight;

    { Render at least InventorySlotsVisibleInColumn slots,
      possibly drawing empty slots. This is needed, because
      otherwise when no items are owned player doesn't see any
      effect of changing InventoryVisible. }
    for I := 0 to Max(Player.Inventory.Count - 1,
      InventorySlotsVisibleInColumn - 1) do
    begin
      X := ItemSlotX(I);
      Y := ItemSlotY(I);

      GLInventorySlot.Alpha := acFullRange;
      GLInventorySlot.Draw(X, Y);
    end;

    for I := 0 to Player.Inventory.Count - 1 do
    begin
      X := ItemSlotX(I);
      Y := ItemSlotY(I);

      Player.Inventory[I].Resource.GLImage.Alpha := acSimpleYesNo;
      Player.Inventory[I].Resource.GLImage.Draw(
        X + InventorySlotMargin, Y + InventorySlotMargin);
    end;

    if Between(Player.InventoryCurrentItem, 0, Player.Inventory.Count - 1) then
    begin
      Theme.Draw(Rectangle(
        ItemSlotX(Player.InventoryCurrentItem) + InventorySlotMargin,
        ItemSlotY(Player.InventoryCurrentItem) + InventorySlotMargin,
        InventorySlotWidth - 2 * InventorySlotMargin,
        InventorySlotHeight - 2 * InventorySlotMargin),
        tiActiveFrame);
    end;

    for I := 0 to Player.Inventory.Count - 1 do
    begin
      X := ItemSlotX(I);
      Y := ItemSlotY(I);

      S := Player.Inventory[I].Resource.Caption;
      if Player.Inventory[I].Quantity <> 1 then
        S += ' (' + IntToStr(Player.Inventory[I].Quantity) + ')';
      UIFontSmall.Print(X + InventorySlotMargin, Y + InventorySlotMargin,
        NameColor, S);
    end;
  end;

  const
    { line number 1 is for "flying" text }
    LineDeadOrWinner = 2;
    LinePressEscape = 3;
    LinePressAttack = 4;
    LineFPS = 5;
    LineShadowVolumesCounts = 6;
    Gray07: TCastleColor = (0.7, 0.7, 0.7, 1.0);
    Gray08: TCastleColor = (0.8, 0.8, 0.8, 1.0);

  function YLine(const Line: Cardinal): Integer;
  begin
    Result := ContainerHeight - UIFont.RowHeight * Line - 10 { margin };
  end;

  procedure DoShowFPS;
  begin
    { Don't display precise Window.FpsFrameTime and Window.FpsRealTime
      each time --- this would cause too much move for player.
      Instead, display DisplayFpsXxxTime that are updated each second. }
    if (DisplayFpsUpdateTick = 0) or
       (TimeTickDiff(DisplayFpsUpdateTick, GetTickCount) >= 1000) then
    begin
      DisplayFpsUpdateTick := GetTickCount;
      DisplayFpsFrameTime := Window.Fps.FrameTime;
      DisplayFpsRealTime := Window.Fps.RealTime;
    end;

    UIFont.Print(0, YLine(LineFPS), Gray07,
      Format('FPS : %f (real : %f). Shapes : %d / %d',
      [DisplayFpsFrameTime, DisplayFpsRealTime,
       SceneManager.Statistics.ShapesRendered, SceneManager.Statistics.ShapesVisible]));
  end;

  procedure DoShowShadowVolumesCounts;
  begin
    if GLFeatures.ShadowVolumesPossible and ShadowVolumes then
      UIFont.Print(0, YLine(LineShadowVolumesCounts), Gray07,
        Format('No shadow %d + zpass %d + zfail (no l cap) %d + zfail (l cap) %d = all %d',
        [ SceneManager.ShadowVolumeRenderer.CountShadowsNotVisible,
          SceneManager.ShadowVolumeRenderer.CountZPass,
          SceneManager.ShadowVolumeRenderer.CountZFailNoLightCap,
          SceneManager.ShadowVolumeRenderer.CountZFailAndLightCap,
          SceneManager.ShadowVolumeRenderer.CountScenes ]));
  end;

  procedure DoShowDeadOrFinishedKeys(const Color: TCastleColor);

    const
      SPressEscapeToExit = 'Press [Escape] to exit to menu.';

    function SPressAttackToRestart: string;
    begin
      Result := 'Press [Interact] (' +
        Input_Interact.Description('not assigned') +
        ') to restart the level.';
    end;

  begin
    UIFont.Print(0, YLine(LinePressEscape), Color, SPressEscapeToExit);
    UIFont.Print(0, YLine(LinePressAttack), Color, SPressAttackToRestart);
  end;

  procedure DoShowDeadInfo;
  begin
    UIFont.Print(0, YLine(LineDeadOrWinner), Red, 'You''re dead.');
    DoShowDeadOrFinishedKeys(Red);
  end;

  procedure DoShowGameWinInfo;
  begin
    UIFont.Print(0, YLine(LineDeadOrWinner), Gray08, 'Game finished.');
    DoShowDeadOrFinishedKeys(Gray08);
  end;

  procedure RenderLifeIndicator(const ALife, AMaxLife: Single;
    const GLFullIndicatorImage: TGLImage;
    const XMove: Integer; const PrintText: boolean);
  const
    IndicatorHeight = 120;
    IndicatorWidth = 40;
    IndicatorMargin = 5;
  var
    LifeMapped: Integer;
    LifeTextPosition, X, Y: Integer;
    LifeText: string;
  begin
    X := XMove + IndicatorMargin;
    Y := IndicatorMargin;
    LifeMapped := Round(MapRange(ALife, 0, AMaxLife, 0, IndicatorHeight));

    { Note that Life may be > MaxLife, and
      Life may be < 0. }
    if LifeMapped >= IndicatorHeight then
      GLFullIndicatorImage.Draw(X, Y) else
    if LifeMapped < 0 then
      GLBlankIndicatorImage.Draw(X, Y) else
    begin
      ScissorEnable(Rectangle(IndicatorMargin, IndicatorMargin,
        ContainerWidth, LifeMapped));
      GLFullIndicatorImage.Draw(X, Y);

      ScissorEnable(Rectangle(IndicatorMargin, IndicatorMargin + LifeMapped,
        ContainerWidth, ContainerHeight));
      GLBlankIndicatorImage.Draw(X, Y);

      ScissorDisable;
    end;

    if PrintText and (ALife > 0) then
    begin
      LifeText := Format('%d', [Round(ALife)]);
      LifeTextPosition := XMove + IndicatorMargin +
        (IndicatorWidth - UIFont.TextWidth(LifeText)) div 2;
      MaxVar(LifeTextPosition, IndicatorMargin);
      UIFont.Print(LifeTextPosition, IndicatorMargin + IndicatorHeight div 2,
        Gray08, LifeText);
    end;
  end;

  procedure PlayerRender2D;
  var
    S: string;
  begin
    RenderLifeIndicator(Player.Life, Player.MaxLife, GLRedIndicatorImage, 0, true);

    if Player.Flying then
    begin
      if Player.FlyingTimeOut > 0 then
        S := Format(' (%d more seconds)', [Floor(Player.FlyingTimeOut)]);
      UIFont.Print(0, ContainerHeight - UIFont.RowHeight - 5 { margin },
        White, 'Flying' + S);
    end;

    if Player.Dead then
      GLFadeRectangle(ParentRect, Red, 1.0) else
    begin
      if Player.Swimming = psUnderWater then
        DrawRectangle(ParentRect, Vector4Single(0, 0, 0.1, 0.5));

      { Possibly, Player.FadeOut* will be applied on top of water effect,
        that's Ok --- they'll mix. }
      GLFadeRectangle(ParentRect, Player.FadeOutColor, Player.FadeOutIntensity);
    end;
  end;

var
  BossLife: Single;
  BossMaxLife: Single;
begin
  if DebugRenderForLevelScreenshot then Exit;

  if Notifications.GetExists then
    GLNotificationsFade.Draw(
      Rectangle(0, 0, ContainerWidth, GLNotificationsFade.Height));

  if Player.InventoryVisible then
    DoRenderInventory;

  if ShowDebugInfo then
  begin
    DoShowFPS;
    DoShowShadowVolumesCounts;
  end;

  if Player.Dead then
    DoShowDeadInfo;

  if GameWin then
    DoShowGameWinInfo;

  if (SceneManager.Logic <> nil) and
     (SceneManager.Logic is TBossLevel) and
     TBossLevel(SceneManager.Logic).BossIndicator(BossLife, BossMaxLife) then
  begin
    RenderLifeIndicator(BossLife, BossMaxLife,
      GLBossIndicatorImage, ContainerWidth - 150, false);
  end;

  PlayerRender2D;
end;

{ TCastle1SceneManager ------------------------------------------------------- }

function TCastle1SceneManager.PointingDeviceActivate3D(const Item: T3D;
  const Active: boolean; const Distance: Single): boolean;
const
  VisibleDistance = 60.0;
var
  S: string;
  I: TItemOnWorld;
  C: TCreature;
begin
  Result := inherited;
  if Result then Exit;

  if Active and
     ( (Item is TItemOnWorld) or
       (Item is TCreature) ) and
     (Distance <= VisibleDistance) then
  begin
    if Item is TCreature then
    begin
      C := TCreature(Item);
      S := Format('You see a creature "%s"', [C.Resource.Name]);

      if C.Life >= C.MaxLife then
        S += ' (not wounded)' else
      if C.Life >= C.MaxLife / 3 then
        S += ' (wounded)' else
      if C.Life > 0 then
        S += ' (very wounded)' else
        S += ' (dead)';
    end else
    begin
      I := TItemOnWorld(Item);
      S := Format('You see an item "%s"', [I.Item.Resource.Caption]);
      if I.Item.Quantity <> 1 then
        S += Format(' (quantity %d)', [I.Item.Quantity]);
    end;

    Notifications.Show(S);
    Result := true;
  end;
end;

procedure Update(Container: TUIContainer);
const
  GameWinPosition1: TVector3Single = (30.11, 146.27, 1.80);
  GameWinPosition2: TVector3Single = (30.11, 166.27, 1.80);
  GameWinDirection: TVector3Single = (0, 1, 0);
  GameWinUp: TVector3Single = (0, 0, 1);
var
  Cages: TCagesLevel;
begin
  LevelFinishedFlush;

  if GameWin and (SceneManager.Logic is TCagesLevel) then
  begin
    Cages := TCagesLevel(SceneManager.Logic);
    case Cages.GameWinAnimation of
      gwaNone:
        begin
          Assert(not Player.Camera.Animation);
          Player.Camera.AnimateTo(GameWinPosition1, GameWinDirection, GameWinUp, 4);
          Cages.GameWinAnimation := Succ(Cages.GameWinAnimation);
        end;
      gwaAnimateTo1:
        if not Player.Camera.Animation then
        begin
          SoundEngine.Sound(stKeyDoorUse);
          Player.Camera.AnimateTo(GameWinPosition2, GameWinDirection, GameWinUp, 4);
          Cages.GameWinAnimation := Succ(Cages.GameWinAnimation);
        end;
      gwaAnimateTo2:
        if not Player.Camera.Animation then
          Cages.GameWinAnimation := Succ(Cages.GameWinAnimation);
    end;
  end;
end;

procedure LevelFinishedFlush;
var
  ImageBackground: TCastleImageControl;
begin
  if LevelFinishedSchedule then
  begin
    LevelFinishedSchedule := false;

    { create a background image when loading new level.
      SceneManager will initialize progress bar when SceneManager.Level
      will be released, so the background will be completely black
      if we don't set something up here. }
    ImageBackground := TCastleImageControl.Create(nil);
    try
      { TODO: nicer image background: blur or such? }
      ImageBackground.Image := Window.SaveScreen;
      Window.Controls.InsertBack(ImageBackground);

      SceneManager.LoadLevel(LevelFinishedNextLevelName);
    finally
      { this will also remove ImageBackground from Window.Controls }
      FreeAndNil(ImageBackground);
    end;
  end;
end;

procedure GameCancel(RequireConfirmation: boolean);
begin
  if Player.Dead or GameWin or (not RequireConfirmation) or
    MessageYesNo(Window, 'Are you sure you want to end the game ?') then
  begin
    GameEndedWantsRestart := '';
    GameEnded := true;
  end;
end;

procedure Press(Container: TUIContainer; const Event: TInputPressRelease);

  procedure UseLifePotion;
  var
    UsedItemIndex: Integer;
  begin
    UsedItemIndex := Player.Inventory.FindResource(LifePotion);
    if UsedItemIndex <> -1 then
      Player.UseItem(UsedItemIndex) else
      Notifications.Show('You don''t have any life potion');
  end;

  procedure DoDebugMenu;
  begin
    SceneManager.Paused := true;
    ShowDebugMenu(GameControls);
    SceneManager.Paused := false;
  end;

  procedure RestartLevel;
  begin
    { normal interaction is already handled because
      TCastleSceneManager.Input_Interact is equal to interact key. }
    if GameWin or Player.Dead then
    begin
      GameEndedWantsRestart := SceneManager.Info.Name;
      GameEnded := true;
    end;
  end;

begin
  if Event.IsKey(CharEscape) then
  begin
    if Player.Dead or GameWin then
      GameCancel(false) else
    begin
      SceneManager.Paused := true;
      ShowGameMenu(GameControls);
      PlayerUpdateMouseLook(Player);
      SceneManager.Paused := false;
    end;
  end;

  if (Player <> nil) and not (Player.Blocked or Player.Dead) then
  begin
    if Input_UseLifePotion.IsEvent(Event) then
      UseLifePotion;
  end;

  { Other keys. }
  if Input_ViewMessages.IsEvent(Event) then
    ViewGameMessages else
  if Input_FPSShow.IsEvent(Event) then
    ShowDebugInfo := not ShowDebugInfo else
  if Input_Interact.IsEvent(Event) then
    RestartLevel else
  if Input_DebugMenu.IsEvent(Event) then
    DoDebugMenu;
end;

procedure CloseQuery(Container: TUIContainer);
begin
  GameCancel(true);
end;

procedure PlayGame(PrepareNewPlayer: boolean);
var
  SavedMode: TGLMode;
  C2D: TGame2DControls;
begin
  GameWin := false;

  LevelFinishedSchedule := false;

  SavedMode := TGLMode.CreateReset(Window, nil, nil, @CloseQuery);
  try
    Window.AutoRedisplay := true;

    Window.OnUpdate := @Update;
    Window.OnPress := @Press;
    Window.RenderStyle := rs3D;

    C2D := TGame2DControls.Create(nil);
    GameControls := TUIControlList.Create(nil);
    GameControls.InsertFront(SceneManager);
    GameControls.InsertFront(C2D);
    GameControls.InsertFront(Notifications);

    Window.Controls.InsertBack(GlobalCatchInput);
    Window.Controls.InsertBack(GameControls);

    GameEnded := false;
    GameEndedWantsRestart := '';

    Theme.Images[tiWindow] := WindowDarkTransparent;

    if PrepareNewPlayer then
      SceneManager.Logic.PrepareNewPlayer(Player);

    Notifications.Show('Hint: press "Escape" for game menu');

    repeat
      Application.ProcessMessage(true, true);
    until GameEnded;
  finally
    { Clear some Player.Camera callbacks. }
    SceneManager.OnCameraChanged := nil;

    FreeAndNil(GameControls);
    FreeAndNil(C2D);
    FreeAndNil(SavedMode);
  end;
end;

procedure LevelFinished(NextLevelName: string);
begin
  if NextLevelName = '' then
  begin
    Notifications.Show('Congratulations, game finished');
    GameWin := true;
    Player.Blocked := true;
    SoundEngine.MusicPlayer.Sound := stGameWinMusic;
  end else
  begin
    if LevelFinishedSchedule and
      (LevelFinishedNextLevelName <> NextLevelName) then
      raise EInternalError.Create(
        'You cannot call LevelFinished while previous LevelFinished is not done yet');

    LevelFinishedSchedule := true;
    LevelFinishedNextLevelName := NextLevelName;
  end;
end;

type
  TGamePlay = class
    class function CreatureExists(const Creature: TCreature): boolean;
    class function ItemOnWorldExists(const Item: TItemOnWorld): boolean;
  end;

class function TGamePlay.CreatureExists(const Creature: TCreature): boolean;
begin
  Result := not GameWin;
end;

class function TGamePlay.ItemOnWorldExists(const Item: TItemOnWorld): boolean;
begin
  Result := (not GameWin) and (not DebugRenderForLevelScreenshot);
end;

{ initialization / finalization ---------------------------------------------- }

procedure ContextOpen;

  function PlayerControlURL(const BaseName: string): string;
  begin
    Result := ApplicationData('player_controls/' + BaseName);
  end;

  function LoadPlayerControlToGL(const BaseName: string): TGLImage;
  begin
    Result := TGLImage.Create(PlayerControlURL(BaseName), [TRGBAlphaImage]);
  end;

begin
  GLNotificationsFade := LoadPlayerControlToGL('fade.png');
  GLInventorySlot := LoadPlayerControlToGL('item_slot.png');
  GLBlankIndicatorImage := LoadPlayerControlToGL('blank.png');
  GLRedIndicatorImage := LoadPlayerControlToGL('red.png');
  GLBlueIndicatorImage := LoadPlayerControlToGL('blue.png');
  GLBossIndicatorImage := LoadPlayerControlToGL('boss.png');
end;

procedure ContextClose;
begin
  FreeAndNil(GLNotificationsFade);
  FreeAndNil(GLInventorySlot);
  FreeAndNil(GLBlankIndicatorImage);
  FreeAndNil(GLRedIndicatorImage);
  FreeAndNil(GLBlueIndicatorImage);
  FreeAndNil(GLBossIndicatorImage);
end;

initialization
  ShowDebugInfo := false;
  OnGLContextOpen.Add(@ContextOpen);
  OnGLContextClose.Add(@ContextClose);
  OnCreatureExists := @TGamePlay(nil).CreatureExists;
  OnItemOnWorldExists := @TGamePlay(nil).ItemOnWorldExists;
  T3DOrient.DefaultOrientation := otUpZDirectionX;
end.