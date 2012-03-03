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
  GameVideoOptions, CastleScene, X3DNodes, Base3D, DOM,
  FGL {$ifdef VER2_2}, FGLObjectList22 {$endif};

type
  { Resource used for rendering and processing of 3D objects.
    By itself this doesn't render or do anything.
    But some 3D objects may need to have such resource prepared to work.

    It can also load it's configuration from XML config file.
    For this purpose, it has a unique identifier in @link(Id) property. }
  T3DResource = class
  private
  { Internal design notes: Having resource expressed as
    T3DResource instance, as opposed to overusing dummy T3D instances
    for it, is sometimes good. That's because such resource may be shared by many
    3D objects, may be used for different purposes by various 3D objects
    (e.g. various creatures may be in different state / animation time),
    it's users (3D objects) may not always initially exist on the level
    (e.g. TItem, that is not even T3D, may refer to it), etc.
    There were ideas to unify T3DResource to be like a T3D descendant
    (or ancestor), but they turned out to cause more confusion (special cases,
    special treatment) than the gain from unification (which would
    be no need of Resources list in TCastleSceneManager, simple
    TCastleSceneManager.Items would suffice.) }

    FId: string;
    Allocated: T3DListCore;
    FUsageCount: Cardinal;
  protected
    { Prepare 3D resource loading it from given filename.
      Loads the resource only if filename is not empty,
      and only if it's not already loaded (that is, when Anim = nil).
      Sets rendering attributes and prepares for fast rendering
      and other processing by T3D.PrepareResources.

      Call only in PrepareCore overrides.

      It calls Progress.Step 2 times.

      Animation or Scene is automatically added to our list of prepared
      3D resources.
      So it's OpenGL resources will be automatically released in
      @link(GLContextClose), it will be fully released
      in @link(ReleaseCore) and destructor.

      @param(AnimationName is here only for debug purposes (it may be used
        by some debug messages etc.))

      @groupBegin }
    procedure PreparePrecalculatedAnimation(
      const AnimationName: string;
      var Anim: TCastlePrecalculatedAnimation;
      const AnimationFile: string;
      const BaseLights: TLightInstancesList);
    procedure PrepareScene(
      var Scene: TCastleScene;
      const SceneFileName: string;
      const BaseLights: TLightInstancesList);
    { @groupEnd }

    { Prepare or release everything needed to use this resource.
      PrepareCore and ReleaseCore should never be called directly,
      they are only to be overridden in descendants.
      These are used by actual @link(Prepare) and @link(Release)
      when the actual allocation / deallocation should take place
      (when required counter raises from zero or drops back to zero).

      ReleaseCore is also called in destructor, regardless of required count.
      This is done to free resources even if user forgot to call Release
      before destroying this resource instance.

      PrepareCore must call Progress.Step exactly PrepareCoreSteps times.
      This allows to make nice progress bar in @link(Prepare).
      In this class, PrepareCoreSteps returns 0.
      @groupBegin }
    procedure PrepareCore(const BaseLights: TLightInstancesList); virtual;
    function PrepareCoreSteps: Cardinal; virtual;
    procedure ReleaseCore; virtual;
    { @groupEnd }
  public
    constructor Create(const AId: string); virtual;
    destructor Destroy; override;

    { Are we in prepared state, that is after @link(Prepare) call and before @link(Release). }
    function Prepared: boolean;

    { Free any association with current OpenGL context. }
    procedure GLContextClose; virtual;

    { Unique identifier of this creature kind.
      Used to refer to this kind from VRML/X3D models, XML files and other data.

      This must be composed of only letters, use CamelCase.
      (Reason: This must be a valid identifier in all possible languages.
      Also digits and underscore are reserved, as we may use them internally
      for other info in VRML/X3D and XML node names.) }
    property Id: string read FId;

    procedure LoadFromFile(KindsConfig: TCastleConfig); virtual;

    { Release and then immediately prepare again this resource.
      Call only when UsageCount <> 0, that is when resource is prepared.
      Shows nice progress bar, using @link(Progress). }
    procedure RedoPrepare(const BaseLights: TLightInstancesList);

    { How many times this resource is used. Used by Prepare and Release:
      actual allocation / deallocation happens when this raises from zero
      or drops back to zero. }
    property UsageCount: Cardinal
      read FUsageCount write FUsageCount default 0;

    { Prepare or release everything needed to use this resource.

      There is an internal counter tracking how many times given
      resource was prepared and released. Which means that preparing
      and releasing resource multiple times is correct --- but make
      sure that every single call to prepare is paired with exactly one
      call to release. Actual allocation / deallocation
      (when protected methods PrepareCore, ReleaseCore are called)
      happens only when required count raises from zero or drops back to zero.

      Show nice progress bar, using @link(Progress).

      @groupBegin }
    procedure Require(const BaseLights: TLightInstancesList);
    procedure UnRequire;
    { @groupEnd }
  end;

  T3DResourceClass = class of T3DResource;

  T3DResourceList = class(specialize TFPGObjectList<T3DResource>)
  private
    procedure LoadIndexXml(const FileName: string);
  public
    { Find resource with given T3DResource.Id.
      @raises Exception if not found. }
    function FindId(const AId: string): T3DResource;

    { Load all items configuration from XML files. }
    procedure LoadFromFile;

    { Reads <resources_required> XML element. <resources_required> element
      is required child of given ParentElement.
      Sets current list value with all mentioned required
      resources (subset of AllResources). }
    procedure LoadRequiredResources(ParentElement: TDOMElement);

    { Make sure given resource is required.
      Internally, requiring a resource increases it's usage count.
      The actual allocated memory is only released one required count gets back
      to zero.
      @groupBegin }
    procedure Require(const BaseLights: TLightInstancesList;
      const ResourcesName: string = 'resources');
    procedure UnRequire;
    { @groupEnd }
  end;

var
  AllResources: T3DResourceList;

{ Register a class, to allow user to create creatures/items of this class
  by using appropriate type="xxx" inside index.xml file. }
procedure RegisterResourceClass(const AClass: T3DResourceClass; const TypeName: string);

implementation

uses SysUtils, ProgressUnit, GameWindow, CastleXMLUtils, CastleTimeUtils,
  CastleStringUtils, CastleLog, CastleFilesUtils, PrecalculatedAnimationCore,
  CastleWindow;

type
  TResourceClasses = specialize TFPGMap<string, T3DResourceClass>;
var
  ResourceClasses: TResourceClasses;

{ T3DResource ---------------------------------------------------------------- }

constructor T3DResource.Create(const AId: string);
begin
  inherited Create;
  FId := AId;
  Allocated := T3DListCore.Create(true, nil);
end;

destructor T3DResource.Destroy;
begin
  ReleaseCore;
  FreeAndNil(Allocated);
  inherited;
end;

procedure T3DResource.PrepareCore(const BaseLights: TLightInstancesList);
begin
end;

function T3DResource.PrepareCoreSteps: Cardinal;
begin
  Result := 0;
end;

procedure T3DResource.ReleaseCore;
begin
  if Allocated <> nil then
  begin
    { since Allocated owns all it's items, this is enough to free them }
    Allocated.Clear;
  end;
end;

procedure T3DResource.GLContextClose;
var
  I: Integer;
begin
  for I := 0 to Allocated.Count - 1 do
    Allocated[I].GLContextClose;
end;

procedure T3DResource.LoadFromFile(KindsConfig: TCastleConfig);
begin
  { Nothing to do in this class. }
end;

procedure T3DResource.RedoPrepare(const BaseLights: TLightInstancesList);
begin
  Assert(UsageCount <> 0);
  Progress.Init(PrepareCoreSteps, 'Loading ' + Id);
  try
    { It's important to do ReleaseCore after Progress.Init.
      That is because Progress.Init does TCastleWindowBase.SaveScreenToDisplayList,
      and this may call Window.OnDraw, and this may want to redraw
      the object (e.g. if creature of given kind already exists
      on the screen) and this requires Prepare to be already done.

      So we should call Progress.Init before we make outselves unprepared. }
    ReleaseCore;
    PrepareCore(BaseLights);
  finally Progress.Fini; end;
end;

procedure T3DResource.PreparePrecalculatedAnimation(
  const AnimationName: string;
  var Anim: TCastlePrecalculatedAnimation;
  const AnimationFile: string;
  const BaseLights: TLightInstancesList);
begin
  if (AnimationFile <> '') and (Anim = nil) then
  begin
    Anim := TCastlePrecalculatedAnimation.CreateCustomCache(nil, GLContextCache);
    Allocated.Add(Anim);
    Anim.LoadFromFile(AnimationFile, { AllowStdIn } false, { LoadTime } true,
      { rescale scenes_per_time }
      AnimationScenesPerTime / DefaultKAnimScenesPerTime);
  end;
  Progress.Step;

  if Anim <> nil then
  begin
    if Log then
      WritelnLog('Animation info',
        Format('%40s %3d scenes * %8d triangles',
        [ Id + '.' + AnimationName + ' animation: ',
          Anim.ScenesCount,
          Anim.Scenes[0].TrianglesCount(true) ]));

    AttributesSet(Anim.Attributes);
    Anim.PrepareResources([prRender, prBoundingBox] + prShadowVolume,
      false, BaseLights);
  end;
  Progress.Step;
end;

procedure T3DResource.PrepareScene(
  var Scene: TCastleScene;
  const SceneFileName: string;
  const BaseLights: TLightInstancesList);
begin
  if (SceneFileName <> '') and (Scene = nil) then
  begin
    Scene := TCastleScene.CreateCustomCache(nil, GLContextCache);
    Allocated.Add(Scene);
    Scene.Load(SceneFileName);
  end;
  Progress.Step;

  if Scene <> nil then
  begin
    AttributesSet(Scene.Attributes);
    Scene.PrepareResources([prRender, prBoundingBox] + prShadowVolume,
      false, BaseLights);
  end;
  Progress.Step;
end;

procedure T3DResource.Require(const BaseLights: TLightInstancesList);
var
  List: T3DResourceList;
begin
  List := T3DResourceList.Create(false);
  try
    List.Add(Self);
    List.Require(BaseLights);
  finally FreeAndNil(List) end;
end;

procedure T3DResource.UnRequire;
var
  List: T3DResourceList;
begin
  List := T3DResourceList.Create(false);
  try
    List.Add(Self);
    List.UnRequire;
  finally FreeAndNil(List) end;
end;

function T3DResource.Prepared: boolean;
begin
  Result := UsageCount <> 0;
end;

{ T3DResourceList ------------------------------------------------------------- }

procedure T3DResourceList.LoadIndexXml(const FileName: string);
var
  Xml: TCastleConfig;
  ResourceClassName, ResourceId: string;
  ResourceClassIndex: Integer;
  Resource: T3DResource;
begin
  Xml := TCastleConfig.Create(nil);
  try
    Xml.RootName := 'resource';
    Xml.NotModified; { otherwise changing RootName makes it modified, and saved back at freeing }
    Xml.FileName := FileName;
    if Log then
      WritelnLog('Resources', Format('Loading T3DResource from "%s"', [FileName]));
    ResourceClassName := Xml.GetNonEmptyValue('type');
    ResourceId := Xml.GetNonEmptyValue('id');
    ResourceClassIndex := ResourceClasses.IndexOf(ResourceClassName);
    if ResourceClassIndex <> -1 then
    begin
      Resource := ResourceClasses.Data[ResourceClassIndex].Create(ResourceId);
      Add(Resource);
      Resource.LoadFromFile(Xml);
    end else
      raise Exception.CreateFmt('Resource type "%s" not found, mentioned in file "%s"',
        [ResourceClassName, FileName]);
  finally FreeAndNil(Xml) end;
end;

procedure T3DResourceList.LoadFromFile;
begin
  ScanForFiles(ProgramDataPath + 'data' + PathDelim + 'creatures', 'index.xml', @LoadIndexXml);
  ScanForFiles(ProgramDataPath + 'data' + PathDelim + 'items', 'index.xml', @LoadIndexXml);
end;

function T3DResourceList.FindId(const AId: string): T3DResource;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
  begin
    Result := Items[I];
    if Result.Id = AId then
      Exit;
  end;

  raise Exception.CreateFmt('Not existing resource name "%s"', [AId]);
end;

procedure T3DResourceList.LoadRequiredResources(ParentElement: TDOMElement);
var
  RequiredResources: TDOMElement;
  ResourceId: string;
  I: TXMLElementIterator;
begin
  Clear;

  RequiredResources := DOMGetChildElement(ParentElement, 'required_resources',
    true);

  I := TXMLElementIterator.Create(RequiredResources);
  try
    while I.GetNext do
    begin
      if I.Current.TagName <> 'resource' then
        raise Exception.CreateFmt(
          'Element "%s" is not allowed in <required_resources>',
          [I.Current.TagName]);
      if not DOMGetAttribute(I.Current, 'id', ResourceId) then
        raise Exception.Create('<resource> must have a "id" attribute');
      Add(AllResources.FindId(ResourceId));
    end;
  finally FreeAndNil(I) end;
end;

procedure T3DResourceList.Require(const BaseLights: TLightInstancesList;
  const ResourcesName: string);
var
  I: Integer;
  Resource: T3DResource;
  PrepareSteps: Cardinal;
  TimeBegin: TProcessTimerResult;
  PrepareNeeded: boolean;
begin
  { We iterate two times over Items, first time only to calculate
    PrepareSteps, 2nd time does actual work.
    1st time increments UsageCount (as 2nd pass may be optimized
    out, if not needed). }

  PrepareSteps := 0;
  PrepareNeeded := false;
  for I := 0 to Count - 1 do
  begin
    Resource := Items[I];
    Resource.UsageCount := Resource.UsageCount + 1;
    if Resource.UsageCount = 1 then
    begin
      PrepareSteps += Resource.PrepareCoreSteps;
      PrepareNeeded := true;
    end;
  end;

  if PrepareNeeded then
  begin
    if Log then
      TimeBegin := ProcessTimerNow;

    Progress.Init(PrepareSteps, 'Loading ' + ResourcesName);
    try
      for I := 0 to Count - 1 do
      begin
        Resource := Items[I];
        if Resource.UsageCount = 1 then
        begin
          if Log then
            WritelnLog('Resources', Format(
              'Resource "%s" becomes required, loading', [Resource.Id]));
          Resource.PrepareCore(BaseLights);
        end;
      end;
    finally Progress.Fini end;

    if Log then
      WritelnLog('Resources', Format('Loading %s time: %f seconds',
        [ ResourcesName,
          ProcessTimerDiff(ProcessTimerNow, TimeBegin) / ProcessTimersPerSec ]));
  end;
end;

procedure T3DResourceList.UnRequire;
var
  I: Integer;
  Resource: T3DResource;
begin
  for I := 0 to Count - 1 do
  begin
    Resource := Items[I];
    Assert(Resource.UsageCount > 0);

    Resource.UsageCount := Resource.UsageCount - 1;
    if Resource.UsageCount = 0 then
    begin
      if Log then
        WritelnLog('Resources', Format(
          'Creature "%s" is no longer required, freeing', [Resource.Id]));
      Resource.ReleaseCore;
    end;
  end;
end;

{ resource classes ----------------------------------------------------------- }

procedure RegisterResourceClass(const AClass: T3DResourceClass; const TypeName: string);
begin
  ResourceClasses[TypeName] := AClass;
end;

{ initialization / finalization ---------------------------------------------- }

procedure WindowClose(Window: TCastleWindowBase);
var
  I: Integer;
begin
  { AllResources may be nil here, because
    WindowClose will be called from CastleWindow unit finalization
    that will be done after this unit's finalization (DoFinalization).

    That's OK --- DoFinalization already freed
    every item on AllResources, and this implicitly did GLContextClose,
    so everything is OK. }

  if AllResources <> nil then
  begin
    for I := 0 to AllResources.Count - 1 do
      AllResources[I].GLContextClose;
  end;
end;

initialization
  Window.OnCloseList.Add(@WindowClose);
  AllResources := T3DResourceList.Create(true);
  ResourceClasses := TResourceClasses.Create;
finalization
  FreeAndNil(AllResources);
  FreeAndNil(ResourceClasses);
end.