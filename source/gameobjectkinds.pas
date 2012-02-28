{
  Copyright 2006-2012 Michalis Kamburelis.

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
unit GameObjectKinds;

interface

uses Classes, CastleXMLConfig, PrecalculatedAnimation,
  GameVideoOptions, CastleScene, X3DNodes;

type
  { This is a common class for item kind and creature kind. }
  TObjectKind = class
  private
    FShortName: string;
    FPrepared: boolean;
  protected
    { Load precalculated animation Anim from given AnimationFile,
      only if Anim = nil.
      It then sets attributes for the animation and prepares
      the animation by TCastlePrecalculatedAnimation.PrepareResources.

      Useful in Prepare overrides.

      It calls Progress.Step 2 times.

      @param(AnimationName is here only for debug purposes (it may be used
      by some debug messages etc.)) }
    procedure CreateAnimationIfNeeded(
      const AnimationName: string;
      var Anim: TCastlePrecalculatedAnimation;
      AnimationFile: string;
      Options: TPrepareResourcesOptions;
      const BaseLights: TLightInstancesList);

    { Read animation filename, reading from XML file KindsConfig.
      The path of responsible XML attribute
      depends on ShortName and given AnimationName.

      If EmptyIfNoAttribute, then this will just set AnimationFile to ''
      if appropriate XML attribute not found. Otherwise
      (when EmptyIfNoAttribute = @false, this is default),
      error will be raised.

      @param(AnimationName determines the XML attribute name, so it must
        be a valid part of XML name) }
    procedure AnimationFromConfig(var AnimationFile: string;
      KindsConfig: TCastleConfig; const AnimationName: string;
      EmptyIfNoAttribute: boolean = false); virtual;

    { Prepare anything needed when starting new game.
      It must call Progress.Step PrepareSteps times.
      It has a funny name to differentiate from Prepare,
      that should be called outside. }
    procedure PrepareInternal(const BaseLights: TLightInstancesList); virtual;
  public
    constructor Create(const AShortName: string);

    procedure Prepare(const BaseLights: TLightInstancesList);

    { How many times Progress.Step will be called during Prepare
      of this object.

      In this class this returns 1 and Prepare will actually do one
      dummy Progress.Step call. That's because this must be > 0,
      some code depends on it, and will optimize out (i.e. not call)
      Prepare if sum of some PrepareSteps will be 0. }
    function PrepareSteps: Cardinal; virtual;

    { Are we in prepared state, that is after @link(Prepare) call and before @link(Release). }
    property Prepared: boolean read FPrepared;

    { Release everything done by Prepare.

      Useful to call e.g. because Prepare must be done once again,
      because some attributes (e.g. things set by AttributesSet) changed.

      In this class this just sets Prepared to @false. }
    procedure Release; virtual;

    { Free any association with current OpenGL context. }
    procedure GLContextClose; virtual;

    { Unique identifier of this creature kind.
      Used to refer to this kind from VRML/X3D models, XML files and other data.

      This must be composed of only letters, use CamelCase.
      (Reason: This must be a valid identifier in all possible languages.
      Also digits and underscore are reserved, as we may use them internally
      for other info in VRML/X3D and XML node names.) }
    property ShortName: string read FShortName;

    procedure LoadFromFile(KindsConfig: TCastleConfig); virtual;

    { This is a debug command, will cause Release
      and then (wrapped within Progress.Init...Fini) will
      call Prepare. This should reload / regenerate all
      things prepared in Prepare. }
    procedure RedoPrepare(const BaseLights: TLightInstancesList);
  end;

implementation

uses SysUtils, ProgressUnit, DOM, GameWindow,
  CastleStringUtils, CastleLog, CastleFilesUtils, PrecalculatedAnimationCore;

constructor TObjectKind.Create(const AShortName: string);
begin
  inherited Create;
  FShortName := AShortName;
end;

procedure TObjectKind.Prepare(const BaseLights: TLightInstancesList);
begin
  FPrepared := true;

  { call this to satisfy Progress.Step = 1 in this class. }
  Progress.Step;

  PrepareInternal(BaseLights);
end;

procedure TObjectKind.PrepareInternal(const BaseLights: TLightInstancesList);
begin
  { Nothing to do here in this class. }
end;

function TObjectKind.PrepareSteps: Cardinal;
begin
  Result := 1;
end;

procedure TObjectKind.Release;
begin
  FPrepared := false;
end;

procedure TObjectKind.GLContextClose;
begin
  { Nothing to do in this class. }
end;

procedure TObjectKind.LoadFromFile(KindsConfig: TCastleConfig);
begin
  { Nothing to do in this class. }
end;

procedure TObjectKind.RedoPrepare(const BaseLights: TLightInstancesList);
begin
  Progress.Init(PrepareSteps, 'Loading object ' + ShortName);
  try
    { It's important to do Release after Progress.Init.
      Why ? Because Progress.Init does TCastleWindowBase.SaveScreeToDisplayList,
      and this may call Window.OnDraw, and this may want to redraw
      the object (e.g. if creature of given kind already exists
      on the screen) and this requires Prepare to be already done.

      So we should call Progress.Init before we invalidate Prepare
      work. }
    Release;

    Prepare(BaseLights);
  finally Progress.Fini; end;
end;

procedure TObjectKind.CreateAnimationIfNeeded(
  const AnimationName: string;
  var Anim: TCastlePrecalculatedAnimation;
  AnimationFile: string;
  Options: TPrepareResourcesOptions;
  const BaseLights: TLightInstancesList);
begin
  if (AnimationFile <> '') and (Anim = nil) then
  begin
    Anim := TCastlePrecalculatedAnimation.CreateCustomCache(nil, GLContextCache);
    Anim.LoadFromFile(AnimationFile, { AllowStdIn } false, { LoadTime } true,
      { rescale scenes_per_time }
      AnimationScenesPerTime / DefaultKAnimScenesPerTime);
  end;
  Progress.Step;

  if Anim <> nil then
  begin
    { Write info before Prepare, otherwise it could not
      be available after freeing scene RootNodes in Anim.Prepare. }
    if Log then
      WritelnLog('Animation info',
        Format('%40s %3d scenes * %8d triangles',
        [ ShortName + '.' + AnimationName + ' animation: ',
          Anim.ScenesCount,
          Anim.Scenes[0].TrianglesCount(true) ]));

    AttributesSet(Anim.Attributes);
    Anim.PrepareResources(Options, false, BaseLights);
  end;
  Progress.Step;
end;

procedure TObjectKind.AnimationFromConfig(var AnimationFile: string;
  KindsConfig: TCastleConfig; const AnimationName: string;
  EmptyIfNoAttribute: boolean);
var
  FileName: string;
begin
  AnimationFile := '';

  FileName := KindsConfig.GetValue(ShortName + '/' + AnimationName + '_animation', '');
  if FileName = '' then
  begin
    if not EmptyIfNoAttribute then
      raise Exception.CreateFmt('Missing "%s_animation" for object "%s"',
        [AnimationName, ShortName]);
  end else
  begin
    AnimationFile := CombinePaths(ExtractFilePath(KindsConfig.FileName), FileName);
  end;
end;

end.