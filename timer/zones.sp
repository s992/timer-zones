#include <sdktools>
#include <sdkhooks>
#include <adminmenu>
#include <timer/zones>

public Plugin myinfo = {
	name = "Timer Zones",
	author = "seaN",
	description = "Manages addition/deletion/editing of zones and tracks client entrance/exit of zones",
	version = "0.0.1",
	url = ""
}

int g_laserMaterial;
int g_haloMaterial;
int g_zoneColors[ ZONE_TYPES_SIZE ][ 4 ];

bool g_lateLoaded;
bool g_pressedUse[ MAXPLAYERS + 1 ] = false;

Handle g_adminMenu = INVALID_HANDLE;
TopMenuObject g_adminZoneMenu;

Handle g_enteredZoneForward = INVALID_HANDLE;
Handle g_exitedZoneForward = INVALID_HANDLE;
Handle g_zoneCreatedForward = INVALID_HANDLE;
Handle g_zoneDeletedForward = INVALID_HANDLE;

Handle g_zones = INVALID_HANDLE;

public APLRes AskPluginLoad2( Handle plugin, bool late ) {

	g_lateLoaded = late;

	CreateNative( "Timer_GetZoneCount", Native_GetZoneCount );

}

public OnPluginStart() {

	RegAdminCmd( "sm_zone", Command_ZoneEdit, ADMFLAG_CONFIG, "Opens zone editing menu" );
	RegAdminCmd( "sm_zones", Command_ZoneEdit, ADMFLAG_CONFIG, "Opens zone editing menu" );
	RegAdminCmd( "sm_zoneadd", Command_StartAddingZone, ADMFLAG_CONFIG, "Starts adding a new zone" );

	g_enteredZoneForward = CreateGlobalForward( "OnTimer_EnteredZone", ET_Event, Param_Cell, Param_Cell );
	g_exitedZoneForward = CreateGlobalForward( "OnTimer_ExitedZone", ET_Event, Param_Cell, Param_Cell );
	g_zoneCreatedForward = CreateGlobalForward( "OnTimer_ZoneCreated", ET_Event, Param_Cell, Param_Cell );
	g_zoneDeletedForward = CreateGlobalForward( "OnTimer_ZoneDeleted", ET_Event, Param_Cell, Param_Cell );

	g_zoneColors[ ZONE_PREVIEW ] = 		{ 255, 255, 255, 255 }; // white
	g_zoneColors[ ZONE_START ] = 		{ 0, 255, 0, 255 }; 	// green
	g_zoneColors[ ZONE_END ] = 			{ 255, 0, 0, 255 }; 	// red
	g_zoneColors[ ZONE_STAGE ] = 		{ 255, 255, 255, 0 }; 	// invisible
	g_zoneColors[ ZONE_CHECKPOINT ] = 	{ 255, 255, 255, 0 }; 	// invisible
	g_zoneColors[ ZONE_BONUS_START ] = 	{ 0, 0, 255, 255 }; 	// blue
	g_zoneColors[ ZONE_BONUS_END ] = 	{ 255, 0, 0, 255 }; 	// red

	g_zones = CreateArray();

	g_laserMaterial = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_haloMaterial = PrecacheModel("materials/sprites/glow01.vmt");

	Handle topmenu;

	if( LibraryExists( "adminmenu" ) && ( topmenu = GetAdminTopMenu() ) != INVALID_HANDLE ) {
		OnAdminMenuReady( topmenu );
	}

	CreateTimer( 1.0, Timer_ShowAdminZone, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

}

public Action OnPlayerRunCmd( client, &buttons ) {

	ZoneEditor editor = ZoneEditor( client );

	if( buttons & IN_USE && editor.active && !g_pressedUse[ client ] ) {

		g_pressedUse[ client ] = true;

		if( editor.step == ADDING_POINTS ) {
			AddPoint( client );
		}

	} else if( g_pressedUse[ client ] && !( buttons & IN_USE ) ) {
		g_pressedUse[ client ] = false;
	}

}

public Action Command_ZoneEdit( int client, args ) {
	AdminMenu_ShowMainMenu( client );
	return Plugin_Handled;
}

public Action Command_StartAddingZone( int client, args ) {
	StartAddingZone( client );
	return Plugin_Handled;
}

StartAddingZone( int client ) {

	ZoneEditor editor = ZoneEditor( client );
	
	if( editor.active ) {
		CloseZoneEditor( client );
	}

	ZoneEditor( client );

}

AddPoint( int client ) {

	ZoneEditor editor = ZoneEditor( client );
	editor.addVertice( GetClientTarget( client ) );

	AdminMenu_ShowAddZonePanel( client );

}

float[3] GetClientTarget( client ) {

	float start[3];
	float angle[3];
	float finish[3];
	Handle trace;

	GetClientEyePosition( client, start );
	GetClientEyeAngles( client, angle );
	trace = TR_TraceRayFilterEx( start, angle, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client );

	if( TR_DidHit( trace ) ) {
		TR_GetEndPosition( finish, trace );
	}

	CloseHandle( trace );

	return finish;

}

public bool TraceRayDontHitSelf( entity, mask, any client ) {
	if( entity == client ) {
		return false;
	}

	return true;
}

public Action Timer_ShowAdminZone( Handle timer ) {

	for( int client = 1; client <= MaxClients; client++ ) {

		ZoneEditor editor = ZoneEditor( client );

		if( editor.active ) {
			DrawZone( editor.vertices, editor.zoneType, editor.client, true );
		}

	}

}

DrawZone( ArrayList vertices, ZoneType zoneType, int client, bool isEditing = false ) {
	if( IsClientInGame( client ) && vertices.Length > 1 ) {

		float startPoint[3];
		float previousPoint[3];
		float currentPoint[3];
		int color[4];

		color = g_zoneColors[ zoneType ];

		// admin needs to be able to see the zone even if it's normally transparent
		if( isEditing && color[3] == 0 ) {
			color = g_zoneColors[ ZONE_PREVIEW ];
		}

		vertices.GetArray( 0, startPoint, 3 );
		previousPoint = startPoint;

		for( int i = 1; i < vertices.Length; i++ ) {

			vertices.GetArray( i, currentPoint, 3 );
			DrawBeam( previousPoint, currentPoint, color, client );
			previousPoint = currentPoint;

		}

		DrawBeam( previousPoint, startPoint, color, client );

	}
}

DrawBeam( float start[3], float end[3], int color[4], int client ) {

	int startFrame = 0;
	int frameRate = 30;
	float life = 1.0;
	float width = 1.0;
	int fadeLength = 0;
	float amplitude = 1.0;
	int speed = 0;

	TE_SetupBeamPoints( start, end, g_laserMaterial, g_haloMaterial, startFrame, frameRate, life, width, width, fadeLength, amplitude, color, speed );
	TE_SendToClient( client );

}

CloseZoneEditor( int client ) {
	ZoneEditor editor = ZoneEditor( client );
	editor.close();
}

SaveZonePoints( int client ) {

	ZoneEditor editor = ZoneEditor( client );
	editor.step = PRE_SAVE;
	AdminMenu_ShowEditZoneMenu( client );

}

DiscardZone( int client ) {
	CloseZoneEditor( client );
}

SaveZone( int client ) {

}

char GetZoneTypeAsString( ZoneType type ) {

	char zoneType[64];

	switch( type ) {
		case ZONE_PREVIEW: Format( zoneType, sizeof( zoneType ), "%s", "Preview" );
		case ZONE_START: Format( zoneType, sizeof( zoneType ), "%s", "Start Zone" );
		case ZONE_END: Format( zoneType, sizeof( zoneType ), "%s", "End Zone" );
		case ZONE_STAGE: Format( zoneType, sizeof( zoneType ), "%s", "Stage" );
		case ZONE_CHECKPOINT: Format( zoneType, sizeof( zoneType ), "%s", "Checkpoint" );
		case ZONE_BONUS_START: Format( zoneType, sizeof( zoneType ), "%s", "Bonus Start Zone" );
		case ZONE_BONUS_END: Format( zoneType, sizeof( zoneType ), "%s", "Bonus End Zone" );
	}

	return zoneType;

}

/* natives */

public int Native_GetZoneCount( Handle plugin, params ) {}

/* menu stuff */

public OnAdminMenuReady( Handle topmenu ) {

	if( topmenu == g_adminMenu ) {
		return;
	}

	g_adminMenu = topmenu;
	g_adminZoneMenu = FindTopMenuCategory( topmenu, "Timer Zones" );

	if( g_adminZoneMenu == INVALID_TOPMENUOBJECT ) {
		g_adminZoneMenu = AddToTopMenu( topmenu, "Timer Zones", TopMenuObject_Category, AdminMenu_MainMenuHandler, INVALID_TOPMENUOBJECT );
	}

	AddToTopMenu( g_adminMenu, "timer_add_zone", TopMenuObject_Item, AdminMenu_MainMenuHandler, g_adminZoneMenu, "timer_add_zone", ADMFLAG_CONFIG );
	AddToTopMenu( g_adminMenu, "timer_edit_zone", TopMenuObject_Item, AdminMenu_MainMenuHandler, g_adminZoneMenu, "timer_edit_zone", ADMFLAG_CONFIG );
	AddToTopMenu( g_adminMenu, "timer_delete_zone", TopMenuObject_Item, AdminMenu_MainMenuHandler, g_adminZoneMenu, "timer_delete_zone", ADMFLAG_CONFIG );

}

public AdminMenu_MainMenuHandler( Handle topmenu, TopMenuAction action, TopMenuObject objectID, int param, char[] buffer, int maxlength ) {

	char name[128];
	GetTopMenuObjName( topmenu, objectID, name, sizeof( name ) );

	switch( action ) {

		case TopMenuAction_DisplayTitle: {

			if( StrEqual( name, "Timer Zones" ) ) {
				Format( buffer, maxlength, "%s", "Timer Zones" );
			}

			if( StrEqual( name, "timer_add_zone" ) ) {
				Format( buffer, maxlength, "%s", "Add Zone" );
			}

			if( StrEqual( name, "timer_edit_zone" ) ) {
				Format( buffer, maxlength, "%s", "Edit Zone" );
			}

			if( StrEqual( name, "timer_delete_zone" ) ) {
				Format( buffer, maxlength, "%s", "Delete Zone" );
			}

		}

		case TopMenuAction_DisplayOption: {

			if( StrEqual( name, "Timer Zones" ) ) {
				Format( buffer, maxlength, "%s", "Timer Zones" );
			}

			if( StrEqual( name, "timer_add_zone" ) ) {
				Format( buffer, maxlength, "%s", "Add Zone" );
			}

			if( StrEqual( name, "timer_edit_zone" ) ) {
				Format( buffer, maxlength, "%s", "Edit Zone" );
			}

			if( StrEqual( name, "timer_delete_zone" ) ) {
				Format( buffer, maxlength, "%s", "Delete Zone" );
			}

		}

		case TopMenuAction_SelectOption: {

			if( StrEqual( name, "timer_add_zone" ) ) {
				StartAddingZone( param );
			}

			if( StrEqual( name, "timer_edit_zone" ) ) {
				PrintToChatAll("Selected timer_edit_zone");
			}

			if( StrEqual( name, "timer_delete_zone" ) ) {
				PrintToChatAll("Selected timer_delete_zone");
			}

		}

	}

}

AdminMenu_ShowMainMenu( int client ) {
	DisplayTopMenuCategory( g_adminMenu, g_adminZoneMenu, client );
}

AdminMenu_ShowAddZonePanel( int client ) {

	Handle panel = CreatePanel();
	ZoneEditor editor = ZoneEditor( client );
	int vertCount = editor.vertices.Length;
	char text[128];

	SetPanelTitle( panel, "Adding zone.." );

	Format( text, sizeof( text ), "Points added: %d", vertCount );
	DrawPanelText( panel, text );

	Format( text, sizeof( text ), "Maximum points: %d", MAX_VERTICES );
	DrawPanelText( panel, text );

	DrawPanelItem( panel, "Save points", ( vertCount >= MIN_VERTICES ) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED );
	DrawPanelItem( panel, "Discard zone" );

	SendPanelToClient( panel, client, AdminMenu_AddZonePanelHandler, MENU_TIME_FOREVER );

	CloseHandle( panel );

}

public AdminMenu_AddZonePanelHandler( Handle menu, MenuAction action, param1, param2 ) {

	if( action == MenuAction_Select ) {

		switch( param2 ) {
			// Save points
			case 1: SaveZonePoints( param1 );
			// Discard zone
			case 2: DiscardZone( param1 );
		}

	}

}

AdminMenu_ShowEditZoneMenu( int client ) {

	Handle menu = CreateMenu( AdminMenu_EditZoneMenuHandler );
	ZoneEditor editor = ZoneEditor( client );
	char text[128];

	SetMenuTitle( menu, "Configure Zone" );

	Format( text, sizeof( text ), "Zone Type: %s", GetZoneTypeAsString( editor.zoneType ) );
	AddMenuItem( menu, "timer_set_zone_type", text );

	AddMenuItem( menu, "timer_adjust_zone_points", "Adjust Points" );
	AddMenuItem( menu, "timer_save_zone", "Save and Activate" );

	if( editor.zoneStatus == ZONE_UNSAVED ) {
		AddMenuItem( menu, "timer_discard_zone", "Discard Zone" );
	}

	DisplayMenu( menu, client, MENU_TIME_FOREVER );

}

public AdminMenu_EditZoneMenuHandler( Handle menu, MenuAction action, param1, param2 ) {

	char name[128];
	GetMenuItem( menu, param2, name, sizeof( name ) );

	switch( action ) {
		case MenuAction_Select: {
			if( StrEqual( name, "timer_set_zone_type" ) ) {
				AdminMenu_ShowEditTypeMenu( param1 );
			}

			if( StrEqual( name, "timer_adjust_zone_points" ) ) {
				AdminMenu_ShowEditPointsMenu( param1 );
			}

			if( StrEqual( name, "timer_save_zone" ) ) {
				SaveZone( param1 );
			}

			if( StrEqual( name, "timer_discard_zone" ) ) {
				DiscardZone( param1 );
			}
		}
		case MenuAction_Cancel: DiscardZone( param1 );
	}

}

AdminMenu_ShowEditTypeMenu( int client ) {

	ZoneEditor editor = ZoneEditor( client );
	Handle menu = CreateMenu( AdminMenu_EditTypeMenuHandler );
	char text[64];

	SetMenuTitle( menu, "Edit Zone Type" );

	// start at 1 to skip "preview" type
	for( int i = 1; i < _:ZONE_TYPES_SIZE; i++ ) {
		Format( text, sizeof( text ), "%s%s", GetZoneTypeAsString( ZoneType:i ), ( ZoneType:i == editor.zoneType ) ? " (current)" : "" )
		AddMenuItem( menu, "zone_type", text );
	}

	DisplayMenu( menu, client, MENU_TIME_FOREVER );

}

public AdminMenu_EditTypeMenuHandler( Handle menu, MenuAction action, param1, param2 ) {

	ZoneEditor editor = ZoneEditor( param1 );
	ZoneType actualZoneType = view_as<ZoneType>( param2 + 1 );

	if( action == MenuAction_Select && ZoneType:0 < actualZoneType < ZONE_TYPES_SIZE ) {
		editor.zoneType = actualZoneType;
		AdminMenu_ShowEditZoneMenu( param1 );
	}

}

AdminMenu_ShowEditPointsMenu( int client ) {

	ZoneEditor editor = ZoneEditor( client );
	Handle menu = CreateMenu( AdminMenu_EditPointsMenuHandler );
	char text[64];

	SetMenuTitle( menu, "Edit Points" );

	for( int i = 0; i < editor.vertices.Length; i++ ) {

		Format( text, sizeof( text ), "Point %d", i + 1 );
		AddMenuItem( menu, "zone_edit_point", text );

	}

	DisplayMenu( menu, client, MENU_TIME_FOREVER );

}

public AdminMenu_EditPointsMenuHandler( Handle menu, MenuAction action, param1, param2 ) {

	if( action == MenuAction_Select ) {
		AdminMenu_ShowEditPointMenu( param1, param2 );
	}

}

AdminMenu_ShowEditPointMenu( int client, int verticeIndex ) {

	ZoneEditor editor = ZoneEditor( client );
	Handle menu = CreateMenu( AdminMenu_EditPointMenuHandler );

	editor.step = EDITING_POINT;
	editor.editingVerticeIndex = verticeIndex;

	SetMenuTitle( menu, "Edit Point" );
	AddMenuItem( menu, "zone_point_X+", "X+" );
	AddMenuItem( menu, "zone_point_X-", "X-" );
	AddMenuItem( menu, "zone_point_Y+", "Y+" );
	AddMenuItem( menu, "zone_point_Y-", "Y-" );
	AddMenuItem( menu, "zone_point_Z+", "Z+" );
	AddMenuItem( menu, "zone_point_Z-", "Z-" );
	AddMenuItem( menu, "zone_point_save", "Save" );
	AddMenuItem( menu, "zone_point_delete", "Delete" );

	DisplayMenu( menu, client, MENU_TIME_FOREVER );

}

public AdminMenu_EditPointMenuHandler( Handle menu, MenuAction action, param1, param2 ) {

	ZoneEditor editor = ZoneEditor( param1 );
	char name[64];
	float vertice[3];

	GetMenuItem( menu, param2, name, sizeof( name ) );

	if( action == MenuAction_Select ) {

		vertice = editor.getEditingVertice();

		if( StrEqual( name, "zone_point_X+" ) ) {
			vertice[0] += 5.0;
		}

		if( StrEqual( name, "zone_point_X-" ) ) {
			vertice[0] -= 5.0;
		}

		if( StrEqual( name, "zone_point_Y+" ) ) {
			vertice[1] += 5.0;
		}

		if( StrEqual( name, "zone_point_Y-" ) ) {
			vertice[1] -= 5.0;
		}

		if( StrEqual( name, "zone_point_Z+" ) ) {
			vertice[2] += 5.0;
		}

		if( StrEqual( name, "zone_point_Z-" ) ) {
			vertice[2] -= 5.0;
		}

		editor.updateVertice( vertice, editor.editingVerticeIndex );
		TE_SetupGlowSprite( vertice, g_haloMaterial, 0.1, 1.0, 100 );
		TE_SendToClient( param1 );

		AdminMenu_ShowEditPointMenu( param1, editor.editingVerticeIndex );

	}

}