class_name AP extends Node

## The game name to connect to. Empty string for TextOnly or HintGame clients.
@export var AP_GAME_NAME := ""
## The tags for your game.
@export var AP_GAME_TAGS: Array[String] = []
## The version of your client. Arbitrary number for you to manage.
@export var AP_CLIENT_VERSION := Version.val(0,0,0)
## The target AP version. Not arbitrary - used in `Connect` packet.
@export var AP_VERSION := Version.val(0,5,0)
## The ItemHandling to use when connecting.
@export var AP_ITEM_HANDLING := ItemHandling.ALL
@export_group("Client Settings")
## Prints what items have been previously collected when reconnecting to a slot.
@export var AP_PRINT_ITEMS_ON_CONNECT := false
## Hide item send messages that don't involve the client.
@export var AP_HIDE_NONLOCAL_ITEMSENDS := true
## Automatically opens a default AP text console.
@export var AP_AUTO_OPEN_CONSOLE := false
@export_subgroup("UI")
## Automatically open the Connection box when the console opens
@export var AP_CONSOLE_CONNECTION_OPEN := false
## Automatically open/close the Connection box based on connected status
@export var AP_CONSOLE_CONNECTION_AUTO := true

@export_subgroup("Logging")
## Enables additional logging.
@export var AP_LOG_COMMUNICATION := false
## Enables additional logging.
@export var AP_LOG_RECIEVED := false
@export_subgroup("Data Packs")
## If true, datapackage local files will be stringified in a readable mode.
@export var READABLE_DATAPACK_FILES := true
## Which fields should be saved from received DataPacks.
@export var datapack_cached_fields: Array[String] = ["item_name_to_id","location_name_to_id","checksum"]
@export_group("Misc")
## Size, in MB, of the websocket inbound buffer. Raising may help if large datapackages are causing disconnections.
@export_range(5, 500, 1, "or_greater", "hide_slider") var websocket_inbuffer_mb: int = 50
@export_group("")

@onready var hang_clock: Timer = $HangTimer

#region Connection packets
# See `ConnectionInfo` (Archipelago.conn) for more signals
signal preconnect ## Emitted before connection is attempted
signal roominfo(conn: ConnectionInfo, json: Dictionary) ## Emitted when `RoomInfo` is received
signal connectionrefused(conn: ConnectionInfo, json: Dictionary) ## Emitted when `ConnectionRefused` is received
signal connected(conn: ConnectionInfo, json: Dictionary) ## Emitted when `Connected` is received
signal printjson(json: Dictionary, plaintext: String) ## Emitted when `PrintJSON` is received
signal disconnected ## Emitted when the connection is lost
#endregion
#region Other signals
signal status_updated ## Signals when 'status' changes
signal all_datapacks_loaded ## Signals when all required datapacks have finished loading
## Emitted when a location should be cleared/deleted from the world, as it has been "already collected"
signal remove_location(loc_id: int)
signal on_tag_change
signal on_attach_console

# Debug purposes
signal _logged_message(msg: String)
#endregion


#region COLORS
class ComplexColor:
	var rich :
		set(val):
			if val is RichColor:
				rich = val
				special = null
				plain = null
			else: rich = null
	var special :
		set(val):
			if val is SpecialColor:
				rich = null
				special = val
				plain = null
			else:
				special = null
	var plain :
		set(val):
			if val is String:
				rich = null
				special = null
				plain = val
			elif val is Color:
				plain = str(val)
			else: plain = null
	static func as_rich(color: RichColor) -> ComplexColor:
		var ret := ComplexColor.new()
		ret.rich = color
		return ret
	static func as_special(color: SpecialColor) -> ComplexColor:
		var ret := ComplexColor.new()
		ret.special = color
		return ret
	static func as_plain(color: String) -> ComplexColor:
		var ret := ComplexColor.new()
		ret.plain = color
		return ret
	func calculate(node: Control) -> Color:
		if rich: return AP.get_rich_color(node, rich)
		if special: return AP.get_special_color(node, special)
		return AP.color_from_name(node, plain)
	static var NIL := as_rich(AP.RichColor.NIL)
enum RichColor {
	NIL, RED, GREEN, YELLOW, BLUE,
	MAGENTA, CYAN, WHITE, BLACK, SLATEBLUE,
	PLUM, SALMON, ORANGE, GOLD,
}
enum SpecialColor {
	PLAYER, ITEM_PROG, ITEM, ITEM_USEFUL, ITEM_TRAP,
	LOCATION, UI_MESSAGE, DEBUG
}

const _special_colors: Dictionary[SpecialColor, RichColor] = {
	SpecialColor.PLAYER: RichColor.MAGENTA,
	SpecialColor.ITEM_PROG: RichColor.PLUM,
	SpecialColor.ITEM: RichColor.CYAN,
	SpecialColor.ITEM_USEFUL: RichColor.SLATEBLUE,
	SpecialColor.ITEM_TRAP: RichColor.SALMON,
	SpecialColor.LOCATION: RichColor.GREEN,
	SpecialColor.UI_MESSAGE: RichColor.GOLD,
	SpecialColor.DEBUG: RichColor.MAGENTA,
}

static func is_rich_color_name(s: String) -> bool:
	if s == "nil": return false
	return RichColor.keys().map(func(c): return str(c).to_lower()).has(s)
static func rich_color_from_name(s: String) -> RichColor:
	var ind: int = RichColor.keys().map(func(c): return str(c).to_lower()).find(s)
	if ind > -1: return RichColor.values()[ind]
	return RichColor.NIL
static func get_rich_color_name(node: Control, s: String, default := Color.WHITE) -> Color:
	if node.has_theme_color("rich_%s" % s, "Console_Label"):
		return node.get_theme_color("rich_%s" % s, "Console_Label")
	return default
static func get_rich_color(node: Control, c: RichColor, default := Color.WHITE) -> Color:
	if c == RichColor.NIL:
		return default
	return get_rich_color_name(node, RichColor.find_key(c).to_lower(), default)
static func get_special_color(node: Control, c: SpecialColor, default := Color.WHITE) -> Color:
	return get_rich_color(node, _special_colors.get(c, RichColor.NIL), default)
static func special_to_rich_color(c: SpecialColor, default := RichColor.NIL) -> RichColor:
	return _special_colors.get(c, default)

static func color_from_name(node: Control, colname: String, def := Color.TRANSPARENT) -> Color:
	return get_rich_color_name(node, colname, Color.from_string(colname, def))
#endregion COLORS

enum ItemHandling {
	NONE = 0, ## Don't receive any items from the server.
	OTHER = 1, ## Receive your items in other worlds from the server.
	OWN_AND_OTHER = 3, ## Receive your items from your world and other worlds from the server.
	STARTING_AND_OTHER = 5, ## Receive your items from your starting inventory and other worlds from the server.
	ALL = 7, ## Receive your items from your starting inventory, your world, and other worlds from the server.
}

var last_sent_deathlink_time: float

## The current connection credentials to be used
var creds: APCredentials = APCredentials.new()
## The current APLock object. A default lock object is "unlocked".
## If an "unlocked" object is set here, it will be "locked" when you connect to a slot.
## If a "locked" object is set here, it will disallow you from connecting to any slot different from the one it locked to.
## Saving an APLock object in a save file allows you to lock it to a particular room.
var aplock: APLock = null

var _socket: WebSocketPeer

var config : APConfigManager ## Will be defaulted if not provided in 'godot_ap/autoloads/archipelago.tscn'
var save_manager : APSaveManager ## Can be 'null' if not provided in 'godot_ap/autoloads/archipelago.tscn'

#region CONNECTION
var conn: ConnectionInfo ## The active Archipelago connection

signal connect_step(message: String)
enum APStatus {
	DISCONNECTED, ## Not connected to any Archipelago server
	SOCKET_CONNECTING, ## Socket attempting to connect
	CONNECTING, ## Socket connected, trying to connect with server
	CONNECTED, ## Connected with server, authenticating for selected slot
	PLAYING, ## Authenticated and acively playing
	DISCONNECTING, ## Attempting to disconnect from the server
}
var _queue_reconnect := false
## The current connection status
var status: APStatus = APStatus.DISCONNECTED :
	set(val):
		if status != val:
			status = val
			status_updated.emit()
		if status == APStatus.DISCONNECTED:
			conn = null
			if _queue_reconnect:
				_queue_reconnect = false
				ap_reconnect()

## Returns true if there is an active Archipelago connection
func is_ap_connected() -> bool:
	return status == APStatus.PLAYING
## Returns true if there is no active Archipelago connection
func is_not_connected() -> bool:
	return status != APStatus.PLAYING

var _connecting_part: Label

var _connect_attempts := 1
var _wss := true

## Returns the URL currently being targetted for connection
func get_url() -> String:
	return "%s://%s:%s" % ["wss" if _wss else "ws",creds.ip,creds.port]

## Reconnect to Archipelago with the same information as before
func ap_reconnect() -> void:
	if status != APStatus.DISCONNECTED:
		ap_disconnect()
		_queue_reconnect = true
		return
	connect_step.emit("Connecting...")
	status = APStatus.SOCKET_CONNECTING
	_connect_attempts = 1
	_wss = true
	preconnect.emit()

## Connect to Archipelago with the specified connection information
func ap_connect(room_ip: String, room_port: String, slot_name: String, room_pwd := "") -> void:
	if status != APStatus.DISCONNECTED:
		ap_disconnect() # Do it here so the ip/port/slot are correct in the disconnect message
	AP.open_logger()
	creds.update(room_ip, room_port, slot_name, room_pwd)
	ap_reconnect()

## Disconnect from Archipelago
func ap_disconnect() -> void:
	if _connecting_part:
		_connecting_part = null
	if status == APStatus.DISCONNECTED or status == APStatus.DISCONNECTING:
		return
	status = APStatus.DISCONNECTING
	connect_step.emit("Disconnecting...")
	_socket.close()
	hang_clock.start(hang_clock.wait_time)
	AP.close_logger()
	if output_console:
		var part := BaseConsole.make_text("Disconnecting...","%s:%s %s" % [creds.ip,creds.port,creds.slot], ComplexColor.as_special(SpecialColor.UI_MESSAGE))
		output_console.add(part)
		while status != APStatus.DISCONNECTED:
			await status_updated
		part.text = "Disconnected from AP."

func force_disconnect() -> void:
	if status == APStatus.DISCONNECTED: return
	_socket.close()
	create_socket()
	status = APStatus.DISCONNECTED
	disconnected.emit()

	for c in all_datapacks_loaded.get_connections():
		if c["flags"] & CONNECT_ONE_SHOT:
			var caller: Callable = c["callable"]
			if caller.get_method() == "send_command" and caller.get_object() == self:
				if caller.get_bound_arguments_count() == 2 and caller.get_bound_arguments()[0] == "Connect":
					all_datapacks_loaded.disconnect(caller)

func create_socket() -> void:
	const BYTE_PER_MB := 1000000
	_socket = WebSocketPeer.new()
	_socket.inbound_buffer_size = websocket_inbuffer_mb*BYTE_PER_MB
#endregion CONNECTION

#region LOGGING TO FILE
static var logging_file = null
## Opens the GodotAP logging file, if it isn't already open
static func open_logger() -> void:
	if not logging_file:
		logging_file = FileAccess.open("user://ap/ap_log.log",FileAccess.WRITE)
## Closes the GodotAP logging file, if its open
static func close_logger() -> void:
	if logging_file:
		logging_file.close()
		logging_file = null
## Logs a message to the GodotAP log
func _log(s: String) -> void:
	if logging_file:
		logging_file.store_line(s)
		if OS.is_debug_build(): logging_file.flush()
	var msg: String = "[AP] %s" % s
	print(msg)
	_logged_message.emit(msg)
static func log(s: Variant) -> void:
	if Archipelago:
		Archipelago._log(str(s))
	else:
		print("[AP!] %s" % s)

## Logs a message to the GodotAP log, but only if AP_LOG_COMMUNICATION is true
func comm_log(pref: String, s: Variant) -> void:
	if not AP_LOG_COMMUNICATION: return
	AP.log("[%s] %s" % [pref,str(s)])
## Logs a message to the GodotAP log, but only in a Debug build
static func dblog(s: Variant) -> void:
	if not OS.is_debug_build(): return
	AP.log(s)
#endregion

var _socket_state: WebSocketPeer.State = WebSocketPeer.STATE_CLOSED
func _poll() -> void:
	while true:
		await get_tree().process_frame
		if status == APStatus.DISCONNECTED:
			continue
		if status == APStatus.SOCKET_CONNECTING:
			match _socket_state:
				WebSocketPeer.STATE_OPEN: # Already connected, disconnect that connection
					ap_disconnect()
					_socket_state = _socket.get_ready_state()
				WebSocketPeer.STATE_CLOSED: # Start a new connection
					var err: Error = _socket.connect_to_url(get_url())
					if err:
						AP.log("Connection to '%s' failed! Retrying (%d)" % [get_url(),_connect_attempts])
						_wss = not _wss
						if _wss: _connect_attempts += 1
					elif output_console and not _connecting_part:
						_connecting_part = output_console.add(BaseConsole.make_text("Connecting...","%s:%s %s" % [creds.ip,creds.port,creds.slot], ComplexColor.as_special(SpecialColor.UI_MESSAGE)))
					_socket_state = _socket.get_ready_state()
				WebSocketPeer.STATE_CONNECTING: # Continue trying to make new connection
					_socket.poll()
					_socket_state = _socket.get_ready_state()
					if _socket_state == WebSocketPeer.STATE_OPEN:
						AP.log("Connected to '%s'!" % get_url())
						status = APStatus.CONNECTING
					elif _socket_state != WebSocketPeer.STATE_CONNECTING:
						if _connect_attempts >= 50:
							_socket.close()
							status = APStatus.DISCONNECTING
							AP.log("Connection to '%s' failed too much! Giving up!" % get_url())
							if output_console and _connecting_part:
								_connecting_part.text = "Connection Failed!"
								_connecting_part.tooltip_text += "\nFailed connecting too many times. Check your connection details, or '/reconnect' to try again."
								_connecting_part = null
						else:
							AP.log("Connection to '%s' failed! Retrying (%d)" % [get_url(),_connect_attempts])
							_wss = not _wss
							if _wss: _connect_attempts += 1
				WebSocketPeer.STATE_CLOSING:
					_socket.poll()
					_socket_state = _socket.get_ready_state()
			continue
		_socket.poll()
		_socket_state = _socket.get_ready_state()
		match _socket_state:
			WebSocketPeer.STATE_CLOSED: # Exited; handle reconnection, or concluding intentional disconnection
				hang_clock.stop()
				if status == APStatus.DISCONNECTING:
					status = APStatus.DISCONNECTED
					disconnected.emit()
				else:
					AP.log("Accidental disconnection; reconnecting!")
					ap_reconnect()
			WebSocketPeer.STATE_OPEN: # Running; handle communication
				while _socket.get_available_packet_count():
					var packet: PackedByteArray = _socket.get_packet()
					var json = JSON.parse_string(packet.get_string_from_utf8())
					if not json is Array:
						json = [json]
					for dict in json:
						_handle_command(dict)

var _printout_recieved_items: bool = false
## Sends a command of the specified name, with the given dictionary as the command arguments, to the Archipelago server
func send_command(cmdname: String, args: Dictionary) -> void:
	args["cmd"] = cmdname
	send_packet([args])
## Sends an array of dictionaries as a packet of commands to the server
func send_packet(obj: Array) -> void:
	var s := JSON.stringify(obj)
	Archipelago.comm_log("SEND", s)
	_socket.send_text(s)
func _handle_command(json: Dictionary) -> void:
	var command = json["cmd"]
	comm_log("RECV", str(json))
	match command:
		"RoomInfo":
			status = APStatus.CONNECTED
			connect_step.emit("Parsing RoomInfo...")
			if output_console and _connecting_part:
				_connecting_part.text = "Authenticating..."
			conn = ConnectionInfo.new()
			conn.serv_version = Version.from(json["version"])
			conn.gen_version = Version.from(json["generator_version"])
			conn.seed_name = json["seed_name"]
			handle_datapackage_checksums(json["datapackage_checksums"])
			var args: Dictionary = {"name":creds.slot,"password":creds.pwd,"uuid":conn.uid,
				"version":AP_VERSION._as_ap_dict(),"slot_data":true}
			args["game"] = AP_GAME_NAME
			args["tags"] = AP_GAME_TAGS
			args["items_handling"] = AP_ITEM_HANDLING
			roominfo.emit(conn, json)
			SignalChooser.new().register_multiple(
				[all_datapacks_loaded, disconnected],
				[send_command.bind("Connect",args), Util.nil])
			_send_datapack_request()
		"ConnectionRefused":
			var err_str := str(json["errors"])
			if output_console and _connecting_part:
				_connecting_part.text = "Connection Refused!"
				_connecting_part.tooltip_text += "\nERROR(S): "+err_str
				_connecting_part = null
			AP.log("Connection errors: %s" % err_str)
			connect_step.emit("ERR: %s" % err_str)
			connectionrefused.emit(conn, json)
			ap_disconnect()
		"Connected":
			conn.player_id = json["slot"]
			conn.team_id = json["team"]
			conn.slot_data = json["slot_data"]
			for plyr in json["players"]:
				conn.players.append(NetworkPlayer.from(plyr))
			var slot_info = json["slot_info"]
			for key in slot_info:
				conn.slots.append(NetworkSlot.from(slot_info[key]))

			if aplock:
				var lock_err := aplock.lock(conn)
				if lock_err:
					_connecting_part.text = "Connection Mismatch! Wrong slot for this save!"
					for s in lock_err:
						_connecting_part.tooltip_text += "\n%s" % s
					_connecting_part = null
					ap_disconnect()
					return

			for loc in json["missing_locations"]:
				if not location_exists(loc):
					conn.slot_locations[loc as int] = false
					#Force this locations to be accessible?

			var server_checked = {}
			for loc in json["checked_locations"]:
				_remove_loc(loc)
				server_checked[loc] = true

			var to_collect: Array[int] = []
			for loc in conn.slot_locations.keys():
				if conn.slot_locations[loc] and not loc in server_checked:
					to_collect.append(loc)
			collect_locations(to_collect)

			# Deathlink stuff?
			# If deathlink stuff, possibly ConnectUpdate to add DeathLink tag?

			status = APStatus.PLAYING
			if output_console and _connecting_part:
				_connecting_part.text = "Connected Successfully!"
				_connecting_part = null

			connect_step.emit("Connected!")
			if AP_PRINT_ITEMS_ON_CONNECT:
				_printout_recieved_items = true
				await get_tree().create_timer(3).timeout
				_printout_recieved_items = false

			connected.emit(conn, json)
		"PrintJSON":
			var s: String = (output_console.printjson_command(json) if output_console
				else BaseConsole.printjson_str(json["data"]))
			AP.log("[PRINT] %s" % s)
			printjson.emit(json, s)
		"DataPackage":
			var packs = json["data"]["games"]
			for game in packs.keys():
				_handle_datapack(game, packs[game])
			_send_datapack_request()
		"ReceivedItems":
			while status != APStatus.PLAYING:
				if status == APStatus.CONNECTED:
					await status_updated
				else: return
			var idx: int = json["index"]
			var items: Array[NetworkItem] = []
			for obj in json["items"]:
				items.append(NetworkItem.from(obj, true))
			var refr_items: Array[NetworkItem] = []
			if idx == 0:
				refr_items.assign(items)
			if items:
				var q := 0
				while q < items.size():
					if _receive_item(idx, items[q]):
						q += 1
					else:
						items.remove_at(q)
					idx += 1
				items.make_read_only()
				conn.obtained_items.emit(items)

			if json["index"] == 0:
				refr_items.make_read_only()
				conn.received_items.assign(refr_items)
				conn.refresh_items.emit(refr_items)
		"RoomUpdate":
			for loc in json.get("checked_locations", []):
				_remove_loc(loc)
			if json.has("players"):
				conn.players.clear()
				for plyr in json["players"]:
					conn.players.append(NetworkPlayer.from(plyr))
			conn.roomupdate.emit(json)
		"Bounced":
			conn.bounce.emit(json)
			var tags: Array = json.get("tags", [])
			if tags.has("DeathLink"):
				var tstamp: float = json["data"].get("time", 0.0)
				if is_equal_approx(tstamp, last_sent_deathlink_time):
					return # Skip deaths from self
				var source: String = json["data"].get("source", "")
				var cause: String = json["data"].get("cause", "")
				conn.deathlink.emit(source, cause, json)
		"LocationInfo":
			conn._on_locinfo(json)
		"Retrieved":
			conn._on_retrieve(json)
		"SetReply":
			conn.setreply.emit(json)
		"InvalidPacket":
			AP.log("[INVALID PACKET] Error with %s of command '%s' (%s)" % [json["type"], json.get("original_cmd", "?"), json["text"]])
		_:
			AP.log("[UNHANDLED PACKET TYPE] %s" % str(json))

#region DATAPACKS
var datapack_cache: Dictionary
var datapack_pending: Array[String] = []
## For each game (key) in the checksums dictionary, requests an update for its datapackage
## if the locally stored checksum does not match the given value
func handle_datapackage_checksums(checksums: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("user://ap/datapacks/") # Ensure the directory exists, for later
	var cachefile: FileAccess = FileAccess.open("user://ap/datapacks/cache.dat", FileAccess.READ)
	if cachefile:
		datapack_cache = cachefile.get_var(true)
		cachefile.close()
	datapack_pending = []
	for game in checksums.keys():
		if datapack_cache.has(game):
			var cached = datapack_cache[game]
			if cached["checksum"] == checksums[game] and cached["fields"] == datapack_cached_fields:
				continue #already up-to-date, matching checksum
		datapack_pending.append(game)

## Caches and stores to disk `data` as the DataCache file for `game`
func _handle_datapack(game: String, data: Dictionary) -> void:
	var data_file := FileAccess.open("user://ap/datapacks/%s.json" % game, FileAccess.WRITE)
	datapack_cache[game] = {"checksum":data["checksum"],"fields":datapack_cached_fields.duplicate()}
	for key in data.keys():
		if not key in datapack_cached_fields:
			data.erase(key)
	data_file.store_string(JSON.stringify(data, "\t" if READABLE_DATAPACK_FILES else ""))
	_data_caches[game] = DataCache.from(data)
	data_file.close()
func _send_datapack_request() -> void:
	if datapack_pending:
		var game = datapack_pending.pop_front()
		connect_step.emit("Fetching DataPackage for '%s'..." % game)
		var req = [{"cmd":"GetDataPackage","games":[game]}]
		send_packet(req)
		_cache_datapacks()
	else:
		connect_step.emit("All DataPackages fetched!")
		_cache_datapacks()
		all_datapacks_loaded.emit()
func _cache_datapacks() -> void:
	var cachefile = FileAccess.open("user://ap/datapacks/cache.dat", FileAccess.WRITE)
	cachefile.store_var(datapack_cache, true)
	cachefile.close()

static var _data_caches: Dictionary[String, DataCache] = {}
## Returns a DataCache for the specified game. If it cannot be found, returns an empty (invalid) DataCache, which can still be used, albeit it will not have the desired data within.
static func get_datacache(game: String) -> DataCache:
	var ret: DataCache = _data_caches.get(game)
	if ret: return ret
	var data_file := FileAccess.open("user://ap/datapacks/%s.json" % game, FileAccess.READ)
	if not data_file:
		return DataCache.new()
	ret = DataCache.from_file(data_file)
	data_file.close()
	_data_caches[game] = ret
	return ret
#endregion DATAPACKS

#region ITEMS
func _receive_item(index: int, item: NetworkItem) -> bool:
	assert(item.dest_player_id == conn.player_id)
	if conn.received_index(index):
		return false # Already recieved, skip
	var data: DataCache = conn.get_gamedata_for_player(conn.player_id)
	var msg := ""
	if item.loc_id < 0:
		if output_console and _printout_recieved_items:
			var flowbox := ConsoleHFlow.new()
			flowbox.add_text_split(conn.get_player().output())
			flowbox.add_text_split(ConsoleLabel.make(" got "))
			flowbox.add_text_split(item.output())
			flowbox.add_text_split(ConsoleLabel.make(" ("))
			flowbox.add_text_split(BaseConsole.make_location(item.loc_id, data))
			flowbox.add_text_split(ConsoleLabel.make(")"))
			output_console.add(flowbox)
		msg = "You found your %s at %s!" % [data.get_item_name(item.id),data.get_loc_name(item.loc_id)]
		_remove_loc(item.loc_id)
	elif item.dest_player_id == item.src_player_id:
		if output_console and _printout_recieved_items:
			var flowbox := ConsoleHFlow.new()
			flowbox.add_text_split(conn.get_player().output())
			flowbox.add_text_split(ConsoleLabel.make(" found their "))
			flowbox.add_text_split(item.output())
			flowbox.add_text_split(ConsoleLabel.make(" ("))
			flowbox.add_text_split(BaseConsole.make_location(item.loc_id, data))
			flowbox.add_text_split(ConsoleLabel.make(")"))
			output_console.add(flowbox)
		msg = "You found your %s at %s!" % [data.get_item_name(item.id),data.get_loc_name(item.loc_id)]
		_remove_loc(item.loc_id)
	else:
		var src_data: DataCache = conn.get_gamedata_for_player(item.src_player_id)
		if output_console and _printout_recieved_items:
			var flowbox := ConsoleHFlow.new()
			flowbox.add_text_split(conn.get_player(item.src_player_id).output())
			flowbox.add_text_split(ConsoleLabel.make(" sent "))
			flowbox.add_text_split(item.output())
			flowbox.add_text_split(ConsoleLabel.make(" to "))
			flowbox.add_text_split(conn.get_player().output())
			flowbox.add_text_split(ConsoleLabel.make(" ("))
			flowbox.add_text_split(BaseConsole.make_location(item.loc_id, src_data))
			flowbox.add_text_split(ConsoleLabel.make(")"))
			output_console.add(flowbox)

		msg = "%s found your %s at their %s!" % [conn.get_player_name(item.src_player_id), data.get_item_name(item.id), src_data.get_loc_name(item.loc_id)]

	conn.obtained_item.emit(item)

	if AP_LOG_RECIEVED:
		AP.log(msg)

	if conn.received_items.size() == index:
		conn.received_items.append(item)
	else:
		if conn.received_items.size() < index+1:
			conn.received_items.resize(index+1)
		conn.received_items[index] = item
	return true
#endregion ITEMS

#region LOCATIONS
func _remove_loc(loc_id: int) -> void:
	if conn and not conn.slot_locations.get(loc_id, false):
		conn.slot_locations[loc_id] = true
		remove_location.emit(loc_id)
## Will call `proc` when the specified location id is "removed" (i.e. collected, either by the player or the server)
## If the location is already removed when you call this, `proc` will be called immediately.
func on_removed_id(loc_id: int, proc: Callable) -> void:
	if conn.slot_locations.get(loc_id, false):
		proc.call()
	else:
		remove_location.connect(func(id:int):
			if id == loc_id:
				proc.call())
## Will call `proc` when the specified location name is "removed" (i.e. collected, either by the player or the server)
## If the location is already removed when you call this, `proc` will be called immediately.
func on_removed(loc_name: String, proc: Callable) -> void:
	on_removed_id(conn.get_gamedata_for_player(conn.player_id).get_loc_id(loc_name), proc)

## Call when a single location is collected and needs to be sent to the server.
func collect_location(loc_id: int) -> void:
	if is_tracker_textclient: return
	_printout_recieved_items = false
	send_command("LocationChecks", {"locations":[loc_id]})
	_remove_loc(loc_id)
## Call when multiple locations are collected and need to be sent to the server at once.
func collect_locations(locs: Array[int]) -> void:
	if is_tracker_textclient: return
	_printout_recieved_items = false
	send_command("LocationChecks", {"locations":locs})
	for loc_id in locs:
		_remove_loc(loc_id)

## Returns if the location exists in the slot or not.
func location_exists(loc_id: int) -> bool:
	return conn.slot_locations.has(loc_id)
## Returns if the location was checked or not. `def` is returned if the location does not exist in the slot.
func location_checked(loc_id: int, def := false) -> bool:
	return conn.slot_locations.get(loc_id, def)
## Returns a list of all location ids
func location_list() -> Array[int]:
	var arr: Array[int] = []
	arr.assign(conn.slot_locations.keys())
	return arr
#endregion LOCATIONS

## Try to reconnect to the current connection details, BUT if it detects errors in the details,
## it will instead prompt the user to enter the details.
func ap_reconnect_to_save() -> void:
	if creds.slot.is_empty() or creds.port.length() != 5:
		if output_console:
			var s = "Connection details required! "
			if aplock and aplock.valid:
				s += "Please reconnect to the room previously used by this save file!"
			else:
				s += "Connect to a room when ready."
			output_console.add(BaseConsole.make_text(s, "", ComplexColor.as_special(SpecialColor.UI_MESSAGE)))
	else:
		ap_reconnect()

func _exit_tree():
	if status != APStatus.DISCONNECTED:
		ap_disconnect()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		AP.close_logger()

#region CONSOLE

var output_console_container: ConsoleContainer = null
var output_console: BaseConsole :
	get: return cmd_manager.console
	set(val): cmd_manager.console = val

## Loads a PackedScene as the active console. This becomes the active scene in the passed SceneTree.
func load_packed_console_as_scene(tree: SceneTree, console: PackedScene) -> bool:
	if output_console: return false
	if not Util.for_all_nodes(console.instantiate(), func(node): return node is ConsoleContainer):
		return false
	await tree.process_frame
	tree.change_scene_to_packed(console)
	await tree.node_added
	assert(tree.current_scene)
	load_console(tree.current_scene, false)
	return true
## Loads a Node as the active console. The window this node is in will be considered the console window.
func load_console(console_scene: Node, as_child := true) -> bool:
	if output_console: return false
	if console_scene is ConsoleContainer:
		output_console_container = console_scene
	elif console_scene is Node:
		output_console_container = Util.for_all_nodes(console_scene,
			func(node):
				return node is ConsoleContainer)
		if not output_console_container:
			return false
	if as_child: add_child.call_deferred(console_scene)
	console_scene.ready.connect(func():
		output_console = output_console_container.console
		output_console_container.typing_bar.send_text.connect(func(s: String):
			cmd_manager.call_cmd(s)
			output_console.scroll_bottom.call_deferred()
			)
		output_console.tree_exiting.connect(close_console)
		output_console_container.typing_bar.cmd_manager = cmd_manager
		on_attach_console.emit())
	return true
## Opens a default Archipelago text console popup
func open_console() -> void:
	if output_console: return
	load_console(load("res://godot_ap/ui/ap_console_window.tscn").instantiate())
## Closes the currently attached console
func close_console() -> void:
	if output_console:
		output_console.close()
		output_console = null

#endregion CONSOLE

## The CommandManager for console commands. New commands can be registered as you like.
var cmd_manager: CommandManager = CommandManager.new()
## Resets the CommandManager used by the archipelago console
func init_command_manager(can_connect: bool, server_autofills: bool = true):
	cmd_manager.reset()
	cmd_manager.register_default(func(mgr: CommandManager, msg: String):
		if msg[0] == "/":
			mgr.console.add(BaseConsole.make_text("Unknown command '%s' - use '/help' to see commands" % msg.split(" ", true, 1)[0], "", ComplexColor.as_special(SpecialColor.UI_MESSAGE)))
		else:
			if _ensure_connected(mgr.console):
				send_command("Say", {"text":msg}))
	if can_connect:
		cmd_manager.register_command(ConsoleCommand.new("/connect")
			.add_help("port", "Connects to a new port, with the same ip/slot/password.")
			.add_help("ip[:port]", "Connects to a new ip+[optional] port, with the same slot/password. (if port omitted, uses 38281)")
			.add_help("ip[:port] slot [pwd]", "Connects to a new ip+port, with a new slot and [optional] password. (if port omitted, uses 38281)")
			.set_call(func(mgr: CommandManager, cmd: ConsoleCommand, msg: String):
				var command_args = msg.split(" ", true, 3)
				if command_args.size() == 2:
					command_args.append(creds.slot)
					command_args.append(creds.pwd)
				elif command_args.size() == 3:
					command_args.append("")
				if command_args.size() != 4:
					cmd.output_usage(mgr.console)
				else:
					var ipport = command_args[1].split(":",1)
					if ipport.is_empty():
						cmd.output_usage(mgr.console)
					if ipport.size() == 1 and ipport[0].length() == 5:
						ipport = [creds.ip,ipport[0]]
					elif ipport.size() == 1:
						ipport.append("38281")
					ap_connect(ipport[0],ipport[1],command_args[2],command_args[3])))
		cmd_manager.register_command(ConsoleCommand.new("/reconnect")
			.add_help("", "Refreshes the connection to the Archipelago server")
			.set_call(func(_mgr: CommandManager, _cmd: ConsoleCommand, _msg: String): ap_reconnect()))
		cmd_manager.register_command(ConsoleCommand.new("/disconnect")
			.add_help_cond("", "Kills the connection to the Archipelago server", is_ap_connected)
			.set_call(func(_mgr: CommandManager, _cmd: ConsoleCommand, _msg: String): ap_disconnect()))
	cmd_manager.register_command(ConsoleCommand.new("/locations")
		.add_help_cond("[filter]", "Lists all locations (optionally matching a filter) for the current slot's game.", is_ap_connected)
		.set_call(func(mgr: CommandManager, _cmd: ConsoleCommand, msg: String):
			if not _ensure_connected(mgr.console): return
			var filt := msg.substr(11)
			var data: DataCache = conn.get_gamedata_for_player()

			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override(&"h_separation", 80)

			var title := "LOCATIONS"
			if filt: title += " (%s)" % filt
			var folder := BaseConsole.make_foldable("[ %s ]" % title, msg, ComplexColor.as_special(SpecialColor.UI_MESSAGE))
			mgr.console.add(folder)
			folder.add(grid)
			folder.fold(false)

			var h1 := BaseConsole.make_text("Location Name:")
			grid.add_child(h1)
			if filt:
				h1.tooltip_text = "Filter: " + filt
			grid.add_child(BaseConsole.make_text("Status:"))

			var ids: Array = data.location_name_to_id.values()
			var _index_dict := {}
			for q in ids.size():
				_index_dict[ids[q]] = q
			ids.sort_custom(func(a,b):
				return _index_dict[b] > _index_dict[a])

			for lid in ids:
				var loc_name = data.get_loc_name(lid)
				if not filt or (filt.to_lower() in loc_name.to_lower()):
					var loc_status := find_hint_status(lid, NetworkHint.Status.NOT_FOUND)
					var color := ComplexColor.as_rich(NetworkHint.status_colors.get(loc_status, RichColor.RED))
					var stat_name: String = NetworkHint.status_names.get(loc_status, "Not Found")
					grid.add_child(BaseConsole.make_text(loc_name, "Location %d" % lid, color))
					grid.add_child(BaseConsole.make_text(stat_name, "", color))
			mgr.console.add_header_spacing()
			))
	cmd_manager.register_command(ConsoleCommand.new("/items")
		.add_help_cond("[filter]", "Lists all items (optionally matching a filter) for the current slot's game.", is_ap_connected)
		.set_call(func(mgr: CommandManager, _cmd: ConsoleCommand, msg: String):
			if not _ensure_connected(mgr.console): return
			var filt := msg.substr(7)
			var data: DataCache = conn.get_gamedata_for_player()

			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override(&"h_separation", 80)

			var title := "ITEMS"
			if filt: title += " (%s)" % filt
			var folder := BaseConsole.make_foldable("[ %s ]" % title, msg, ComplexColor.as_special(SpecialColor.UI_MESSAGE))
			mgr.console.add(folder)
			folder.add(grid)
			folder.fold(false)

			var item_dict := {}
			for item in conn.received_items:
				var dict = item_dict.get(item.id)
				if dict:
					dict[item.flags] = dict.get(item.flags, 0) + 1
				else:
					item_dict[item.id] = {item.flags: 1}

			var ids: Array = data.item_name_to_id.values()
			var _index_dict := {}
			for q in ids.size(): _index_dict[ids[q]] = q
			ids.sort_custom(func(a,b):
				var has_a = item_dict.has(a)
				var has_b = item_dict.has(b)
				if has_a and not has_b:
					return true
				if has_a == has_b:
					return _index_dict[b] > _index_dict[a]
				return false)

			var found_second_column := false
			var found_any := false
			for iid in ids:
				var itm_name = data.get_item_name(iid)
				if not filt or (filt.to_lower() in itm_name.to_lower()):
					found_any = true
					var flag_options = item_dict.get(iid)
					if flag_options:
						found_second_column = true
						break
			var filt_ttip := "Filter: " + filt
			if found_any:
				grid.columns = 2 if found_second_column else 1
				var h1 := BaseConsole.make_text("Item Name:")
				grid.add_child(h1)
				if filt:
					h1.tooltip_text = filt_ttip
				if found_second_column:
					grid.add_child(BaseConsole.make_text("Num Collected:"))
				for iid in ids:
					var itm_name = data.get_item_name(iid)
					if not filt or (filt.to_lower() in itm_name.to_lower()):
						var flag_options = item_dict.get(iid)
						if flag_options:
							for flags in flag_options.keys():
								var c1 := BaseConsole.make_item(iid, flags, data)
								grid.add_child(c1)
								grid.add_child(BaseConsole.make_text("x%d" % flag_options[flags], "", ComplexColor.as_rich(c1.rich_color)))
						else:
							grid.add_child(BaseConsole.make_text(itm_name, "Item %d" % iid))
							if found_second_column:
								grid.add_child(Control.new())
			elif filt:
				grid.add_child(BaseConsole.make_text(
					"No%s items found!" % (" matching" if filt else ""),
					filt_ttip, ComplexColor.as_rich(AP.RichColor.SALMON)))
			mgr.console.add_header_spacing()
			))
	if server_autofills: # Autofill for some AP commands
		cmd_manager.register_command(ConsoleCommand.new("!hint_location")
			.set_autofill(_autofill_locs)
			.add_disable(is_not_connected))
		cmd_manager.register_command(ConsoleCommand.new("!hint")
			.set_autofill(_autofill_items)
			.add_disable(is_not_connected))
		cmd_manager.register_command(ConsoleCommand.new("!help")
			.add_help("", "Displays server-based command help")
			.add_disable(is_not_connected))
		cmd_manager.register_command(ConsoleCommand.new("!remaining")
			.add_disable(is_not_connected))
		cmd_manager.register_command(ConsoleCommand.new("!missing")
			.add_disable(is_not_connected))
		cmd_manager.register_command(ConsoleCommand.new("!checked")
			.add_disable(is_not_connected))
		cmd_manager.register_command(ConsoleCommand.new("!collect")
			.add_disable(is_not_connected))
		cmd_manager.register_command(ConsoleCommand.new("!release")
			.add_disable(is_not_connected))
		cmd_manager.register_command(ConsoleCommand.new("!players")
			.add_disable(is_not_connected))
	cmd_manager.setup_basic_commands()
	if OS.is_debug_build():
		cmd_manager.register_command(ConsoleCommand.new("/send").debug()
			.add_help("", "Cheat-Collects the given location")
			.add_disable(func(): return is_tracker_textclient)
			.set_autofill(_autofill_locs)
			.set_call(func(mgr: CommandManager, cmd: ConsoleCommand, msg: String):
				if not _ensure_connected(mgr.console): return
				var command_args = msg.split(" ", true, 1)
				if command_args.size() > 1 and command_args[1]:
					var data = conn.get_gamedata_for_player(conn.player_id)
					for loc in conn.slot_locations.keys():
						var loc_name := data.get_loc_name(loc)
						if loc_name.strip_edges().to_lower() == command_args[1].strip_edges().to_lower():
							if conn.slot_locations[loc]:
								mgr.console.add(BaseConsole.make_text("Location already sent!", "", ComplexColor.as_special(SpecialColor.UI_MESSAGE)))
							else:
								mgr.console.add(BaseConsole.make_text("Sending location '%s'!" % loc_name, "", ComplexColor.as_special(SpecialColor.UI_MESSAGE)))
								collect_location(loc)
							return
					mgr.console.add(BaseConsole.make_text("Location '%s' not found! Check spelling?" % command_args[1].strip_edges(), "", ComplexColor.as_special(SpecialColor.UI_MESSAGE)))
				else: cmd.output_usage(mgr.console)))
		cmd_manager.register_command(ConsoleCommand.new("/lock_info").debug()
			.add_help("", "Prints the connection lock info")
			.set_call(func(mgr: CommandManager, _cmd: ConsoleCommand, _msg: String):
				mgr.console.add(BaseConsole.make_text("%s" % (str(aplock) if aplock else "No Lock Active"), "", ComplexColor.as_special(SpecialColor.UI_MESSAGE)))))
		cmd_manager.register_command(ConsoleCommand.new("/unlock_connection").debug()
			.add_help("", "Unlocks the connection lock, so that any valid slot can be connected to (instead of only the slot previously connected to)")
			.set_call(func(_mgr: CommandManager, _cmd: ConsoleCommand, _msg: String):
				if aplock:
					aplock.unlock()))
		cmd_manager.register_command(ConsoleCommand.new("/set_tag").debug()
			.add_help("tag [bool]", "Sets a tag for the current connection")
			.set_autofill(func(msg: String):
				var args = msg.split(" ", 2)
				var arg_count := args.size()
				while args.size() < 3: args.append("")
				var ret: Array[String] = []
				var opts: Array[String] = []
				if arg_count < 3:
					opts.assign(["TextOnly","HintGame","Tracker","DeathLink"])
					var matched := false
					for opt in opts:
						if args[1] == opt:
							matched = true
							break
						if opt.to_lower().begins_with(args[1].to_lower()):
							ret.append("%s %s" % [args[0],opt])
					if not matched:
						return ret
					ret.clear()
				opts.assign(["true","false"])
				for opt in opts:
					if arg_count < 3 or opt.to_lower().begins_with(args[2].to_lower()):
						ret.append("%s %s %s" % [args[0],args[1],opt])
				return ret)
			.set_call(func(mgr: CommandManager, cmd: ConsoleCommand, msg: String):
				var args = msg.split(" ", true, 2)
				var state := true
				var tag: String = args[1].strip_edges() if args.size() > 1 else ""
				if tag.is_empty():
					cmd.output_usage(mgr.console)
					return
				if args.size() > 2:
					var s = args[2].to_lower()
					if s == "false": state = false
					elif s != "true":
						cmd.output_usage(mgr.console)
						return
				set_tag(tag, state)
				mgr.console.add(BaseConsole.make_text("Set tag '%s' to %s" % [args[1],state], "", ComplexColor.as_special(SpecialColor.UI_MESSAGE)))))
		cmd_manager.register_command(ConsoleCommand.new("/tags").debug()
			.add_help("", "Prints out your connection tags")
			.set_call(func(mgr: CommandManager, _cmd: ConsoleCommand, _msg: String):
				mgr.console.add(BaseConsole.make_text(str(AP_GAME_TAGS), "", ComplexColor.as_special(SpecialColor.UI_MESSAGE)))))
		cmd_manager.register_command(ConsoleCommand.new("/slot_data").debug()
			.add_help("", "Prints slot_data")
			.add_disable(is_not_connected)
			.set_call(func(mgr: CommandManager, _cmd: ConsoleCommand, _msg: String):
				var folder := BaseConsole.make_foldable("[ SLOT_DATA ]", "/slot_data", ComplexColor.as_special(SpecialColor.UI_MESSAGE))
				mgr.console.add(folder)
				folder.add(BaseConsole.make_indented_block(JSON.stringify(Archipelago.conn.slot_data, "\t"), 25))
				folder.fold(false)
				))
		cmd_manager.setup_debug_commands()

func _autofill_track(msg: String) -> Array[String]:
	var args = msg.split(" ", true, 2)
	if args.size() <= 2:
		var fills: Array[String] = ["locations", "refresh", "vars"]
		if not conn:
			fills.erase("locations")
			fills.erase("vars")
		fills.assign(fills.map(func(s: String):
			return "%s %s" % [args[0],s]))
		if args.size() < 2:
			return fills
		var new_fills: Array[String] = []
		for s in fills:
			if s.to_lower().begins_with(msg.to_lower()):
				new_fills.append(s)
		return new_fills
	return []
func _init():
	init_command_manager(true)
	_update_tags()
	_poll.call_deferred()
func _ready():
	if AP_AUTO_OPEN_CONSOLE:
		# Delayed to prevent some warnings
		get_tree().create_timer(2.0).timeout.connect(open_console)
	create_socket()
	for node in get_children():
		if node is APConfigManager:
			config = node
		elif node is APSaveManager:
			save_manager = node
	if not config:
		config = APConfigManager.new()
		add_child(config)
	# 'save_manager' can be null
enum ItemClassification {
	FILLER = 0b000,
	PROG = 0b001,
	USEFUL = 0b010,
	TRAP = 0b100
}

static func get_item_class_color(flags: int) -> RichColor:
	var spec := SpecialColor.ITEM
	if flags & ItemClassification.PROG:
		spec = SpecialColor.ITEM_PROG
	elif flags & ItemClassification.TRAP:
		spec = SpecialColor.ITEM_TRAP
	elif flags & ItemClassification.USEFUL:
		spec = SpecialColor.ITEM_USEFUL
	return special_to_rich_color(spec)
## Returns the string name representing the combined item classifications flags
static func get_item_classification(flags: int) -> String:
	match flags:
		ItemClassification.PROG:
			return "Progression"
		ItemClassification.USEFUL:
			return "Useful"
		ItemClassification.TRAP:
			return "Trap"
		ItemClassification.FILLER:
			return "Filler"
		_:
			var s := ""
			for q in 3:
				if flags & (1<<q):
					if s:
						s += ","
					s += get_item_classification(1<<q)
			return s

func _cmd_nil(_msg: String): pass
func _autofill_locs(msg: String) -> Array[String]:
	if not conn: return []
	var args = msg.split(" ", true, 1)
	var data: DataCache = conn.get_gamedata_for_player(conn.player_id)
	var locs: Array[String] = []
	locs.assign(data.location_name_to_id.keys())
	var ind := 0
	while ind < locs.size():
		var id: int = data.location_name_to_id[locs[ind]]
		if location_checked(id, true):
			locs.pop_at(ind)
		else: ind += 1
	if args.size() > 1 and args[1]:
		var arg_str = args[1].strip_edges().to_lower()
		if arg_str.begins_with("\""):
			arg_str = arg_str.substr(1)
		if arg_str.ends_with("\""):
			arg_str = arg_str.substr(0,arg_str.length()-1)
		var q := 0
		while q < locs.size():
			if not locs[q].strip_edges().to_lower().begins_with(arg_str):
				locs.pop_at(q)
			else:
				q += 1
	for q in locs.size():
		locs[q] = "%s %s" % [args[0],locs[q]]
	return locs
func _autofill_items(msg: String) -> Array[String]:
	if not conn: return []
	var args = msg.split(" ", true, 1)
	var data: DataCache = conn.get_gamedata_for_player(conn.player_id)
	var itms: Array[String] = []
	itms.assign(data.item_name_to_id.keys())
	if args.size() > 1 and args[1]:
		var arg_str = args[1].strip_edges().to_lower()
		if arg_str.begins_with("\""):
			arg_str = arg_str.substr(1)
		if arg_str.ends_with("\""):
			arg_str = arg_str.substr(0,arg_str.length()-1)
		var q := 0
		while q < itms.size():
			if not itms[q].strip_edges().to_lower().begins_with(arg_str):
				itms.pop_at(q)
			else:
				q += 1
	for q in itms.size():
		itms[q] = "%s %s" % [args[0],itms[q]]
	return itms

var is_tracker_textclient := false
func _update_tags() -> void:
	if status == APStatus.PLAYING:
		send_command("ConnectUpdate", {"tags":AP_GAME_TAGS})
	is_tracker_textclient = false
	for tag in AP_GAME_TAGS:
		if tag == "TextOnly" or tag == "Tracker":
			is_tracker_textclient = true
			break
	on_tag_change.emit()
## Sets a given Archipelago tag (on or off)
func set_tag(tag: String, state := true) -> void:
	if tag.is_empty(): return
	for q in AP_GAME_TAGS.size():
		var t := AP_GAME_TAGS[q]
		if t == tag:
			if not state:
				AP_GAME_TAGS.pop_at(q)
				_update_tags()
			return
	if state:
		AP_GAME_TAGS.append(tag)
		_update_tags()
## Sets the Archipelago connection tags (overwriting all existing tags)
func set_tags(tags: Array[String]) -> void:
	if AP_GAME_TAGS != tags:
		AP_GAME_TAGS.assign(tags)
		_update_tags()

func _ensure_connected(console: BaseConsole) -> bool:
	if status == APStatus.PLAYING:
		return true
	console.add(BaseConsole.make_text("Not connected to Archipelago! Please connect first!", "", ComplexColor.as_special(SpecialColor.UI_MESSAGE)))
	return false

func set_deathlink(state: bool) -> void:
	set_tag("DeathLink", state)

func is_deathlink() -> bool:
	return "DeathLink" in Archipelago.AP_GAME_TAGS

enum ClientStatus {
	CLIENT_UNKNOWN = 0,
	CLIENT_CONNECTED = 5,
	CLIENT_READY = 10,
	CLIENT_PLAYING = 20,
	CLIENT_GOAL = 30
}
func set_client_status(stat: ClientStatus) -> void:
	send_command("StatusUpdate", {"status": stat})

func find_hint_status(loc_id: int, default := NetworkHint.Status.UNSPECIFIED) -> NetworkHint.Status:
	if location_checked(loc_id):
		return NetworkHint.Status.FOUND
	for hint in conn.hints:
		if hint.item.src_player_id == conn.player_id and \
			hint.item.loc_id == loc_id:
			return hint.status
	return default
