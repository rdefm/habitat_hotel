
# This file is auto-generated as part of the release process.  GUT maintainers
# should not change this file manually.
static var class_ref = [
	AudioServer,
	CameraServer,
	ClassDB,
	DisplayServer,
	# excluded: EditorInterface,
	Engine,
	EngineDebugger,
	GDExtensionManager,
	Geometry2D,
	Geometry3D,
	IP,
	Input,
	InputMap,
	JavaClassWrapper,
	JavaScriptBridge,
	Marshalls,
	NativeMenu,
	NavigationMeshGenerator,
	NavigationServer2D,
	# PROJECT PATCH: NavigationServer2DManager/3DManager don't exist on
	# Godot 4.4 (this project's pinned engine, project.godot's
	# config/features -- see addons/gut/error_tracker.gd's patch note for
	# the same reasoning) -- confirmed directly via a parse-error repro,
	# not inferred. Dropped from this auto-generated singleton list rather
	# than gated, since GUT only uses this list to avoid stubbing real
	# singleton names.
	NavigationServer3D,
	OS,
	Performance,
	PhysicsServer2D,
	PhysicsServer2DManager,
	PhysicsServer3D,
	PhysicsServer3DManager,
	ProjectSettings,
	RenderingServer,
	ResourceLoader,
	ResourceSaver,
	ResourceUID,
	TextServerManager,
	ThemeDB,
	Time,
	TranslationServer,
	WorkerThreadPool,
	XRServer
]
static var names = []
static func _static_init():
	for entry in class_ref:
		names.append(entry.get_class())
