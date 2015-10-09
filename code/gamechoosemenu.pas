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

{ }
unit GameChooseMenu;

interface

uses Classes, CastleWindow, CastleUIControls;

{ Allows user to choose one item from MenuItems.
  Displays menu using TCastleGameMenu with ControlsUnder background. }
function ChooseByMenu(ControlsUnder: TUIControlList;
  MenuItems: TStringList): Integer;

implementation

uses SysUtils, CastleControlsImages, CastleImages,
  CastleWindowModes, CastleGLUtils, CastleInputs, CastleMessages,
  CastleOnScreenMenu, GameWindow, GameGeneralMenu, CastleVectors, CastleGameNotifications,
  CastleKeysMouse, CastleControls;

var
  Selected: boolean;
  SelectedIndex: Integer;

type
  TChooseMenu = class(TCastleGameMenu)
    procedure Click; override;
  end;

procedure TChooseMenu.Click;
begin
  inherited;

  Selected := true;
  SelectedIndex := CurrentItem;
end;

{ global things -------------------------------------------------------------- }

var
  ChooseMenu: TChooseMenu;

procedure CloseQuery(Container: TUIContainer);
begin
  MessageOK(Window, 'You can''t exit now.');
end;

function ChooseByMenu(ControlsUnder: TUIControlList;
  MenuItems: TStringList): Integer;
var
  SavedMode: TGLMode;
  OldThemeWindow: TCastleImage;
  I: Integer;
begin
  for I := 0 to MenuItems.Count - 1 do
    ChooseMenu.Add(MenuItems[I]);

  OldThemeWindow := Theme.Images[tiWindow];
  SavedMode := TGLMode.CreateReset(Window, nil, Window.OnResize, @CloseQuery);
  try
    Window.RenderStyle := rs3D;

    { Otherwise messages don't look good, because the text is mixed
      with the menu text. }
    Theme.Images[tiWindow] := WindowDark;

    Window.Controls.MakeSingle(TCastleOnScreenMenu, ChooseMenu);

    Window.Controls.InsertBack(GlobalCatchInput);
    Window.Controls.InsertBack(Notifications);
    Window.Controls.InsertBack(ControlsUnder);

    Selected := false;
    repeat
      Application.ProcessMessage(true, true);
    until Selected;

    Result := SelectedIndex;
  finally
    FreeAndNil(SavedMode);
    Theme.Images[tiWindow] := OldThemeWindow;
  end;
end;

{ initialization / finalization ---------------------------------------------- }

procedure ContextOpen;
begin
  ChooseMenu := TChooseMenu.Create(nil);
end;

procedure ContextClose;
begin
  FreeAndNil(ChooseMenu);
end;

initialization
  OnGLContextOpen.Add(@ContextOpen);
  OnGLContextClose.Add(@ContextClose);
end.