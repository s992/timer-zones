#if defined _timer_zones_included
 #endinput
#endif
#define _timer_zones_included

#define MIN_VERTICES 3
#define MAX_VERTICES 12
#define MAX_ZONES 2048

enum ZoneType {
	ZONE_PREVIEW,
	ZONE_START,
	ZONE_END,
	ZONE_STAGE,
	ZONE_CHECKPOINT,
	ZONE_BONUS_START,
	ZONE_BONUS_END,

	ZONE_TYPES_SIZE
}

enum EditingStep {
	NOT_EDITING,
	ADDING_POINTS,
	EDITING_POINT,
	PRE_SAVE
}

enum ZoneStatus {
	ZONE_UNSAVED,
	ZONE_SAVED
}

bool _editor_activeEditors[ MAXPLAYERS + 1 ] = false;
EditingStep _editor_step[ MAXPLAYERS + 1 ] = { NOT_EDITING, ... };
ZoneType _editor_zoneType[ MAXPLAYERS + 1 ];
ZoneStatus _editor_zoneStatus[ MAXPLAYERS + 1 ];
Handle _editor_vertices[ MAXPLAYERS + 1 ] = { null, ... };
int _editor_editingVerticeAtIndex[ MAXPLAYERS + 1 ];

methodmap ZoneEditor {

	public ZoneEditor( int client ) {

		_editor_activeEditors[ client ] = true;

		if( _editor_step[ client ] == NOT_EDITING ) {
			_editor_step[ client ] = ADDING_POINTS;
		}

		if( _editor_vertices[ client ] == null ) {
			_editor_vertices[ client ] = new ArrayList(3);
		}

		return view_as<ZoneEditor>( client );
	}

	property int client {
		public get() {
			return view_as<int>( this );
		}
	}

	property bool active {
		public get() {
			return _editor_activeEditors[ this.client ];
		}
		public set( bool active ) {
			_editor_activeEditors[ this.client ] = active;
		}
	}

	property EditingStep step {
		public get() {
			return _editor_step[ this.client ];
		}
		public set( EditingStep step ) {
			_editor_step[ this.client ] = step;
		}
	}

	property ZoneType zoneType {
		public get() {
			return _editor_zoneType[ this.client ];
		}
		public set( ZoneType zoneType ) {
			_editor_zoneType[ this.client ] = zoneType;
		}
	}

	property ZoneStatus zoneStatus {
		public get() {
			return _editor_zoneStatus[ this.client ];
		}
		public set( ZoneStatus zoneStatus ) {
			_editor_zoneStatus[ this.client ] = zoneStatus;
		}
	}

	property ArrayList vertices {
		public get() {
			return _editor_vertices[ this.client ];
		}
		public set( ArrayList vertices ) {
			_editor_vertices[ this.client ] = vertices;
		}
	}

	property int editingVerticeIndex {
		public get() {
			return _editor_editingVerticeAtIndex[ this.client ];
		}
		public set( int verticeIndex ) {
			_editor_editingVerticeAtIndex[ this.client ] = verticeIndex;
		}
	}

	public float getEditingVertice() {

		float vertice[3];
		GetArrayArray( this.vertices, this.editingVerticeIndex, vertice, 3 );

		return vertice;

	}

	public void addVertice( float[3] vertice ) {
		this.vertices.PushArray( vertice );
	}

	public void updateVertice( float[3] vertice, int index ) {
		this.vertices.SetArray( index, vertice );
	}

	public void close() {
		CloseHandle( _editor_vertices[ this.client ] );
		_editor_step[ this.client ] = NOT_EDITING;
		_editor_zoneType[ this.client ] = ZONE_PREVIEW;
		_editor_zoneStatus[ this.client ] = ZONE_UNSAVED;
		_editor_vertices[ this.client ] = null;
		_editor_editingVerticeAtIndex[ this.client ] = -1;
		_editor_activeEditors[ this.client ] = false;
	}

}