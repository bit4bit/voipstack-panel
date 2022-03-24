

type SoftswitchSource = string;

type Realm = string;
type UnixTimestamp = number;
type LegNumber = string;
type LegName = string

type Tag = string;
type Tags = Set<Tag>;

type SoftswitchEventContent = Map<string, string | number | null >;
interface SoftswitchEvent {
    source: string
    content: SoftswitchEventContent;
}
type SoftswitchCommand = string
type SoftswitchCommandArgument = string

interface Call {
    caller_id_name: LegName;
    caller_id_number: LegNumber;
    callee_id_name: LegName;
    callee_id_number: LegNumber;
    created_at: UnixTimestamp;
    answered_at: UnixTimestamp;
    hangup_at: UnixTimestamp;

    // etiquetamos la llamada, ejemplos: inbound,
    // callcenter-queue:7000@pruebas.org
    tags: Tags;
    // al superar esta fecha se elimina del cache
    persist_up_to: UnixTimestamp;
}

// representa el registro sip actual de una extension
interface Extension {
    name: string;
    realm: Realm;
    expires_at: UnixTimestamp;
    calls: Call[];

    tags: Tags;

    // refrescar con cada cambio de los atributos
    persist_up_to: UnixTimestamp;
}

// representa el estado del softswitch
class Softswitch {
    id: string;
    source: SoftswitchSource;
    version: string;
    extensions: Extension[];
}

interface SoftswitchState {
    source: string
}

interface FreeswitchState extends SoftswitchState {
}

interface AsteriskState {
}

var softswitch = new Softswitch();
var _version = 333;

declare  function dispatch(source : SoftswitchSource, event : SoftswitchEventContent) : void;

function handle_softswitch_state(state : FreeswitchState | AsteriskState) {
}

function handle_panel_command(cmd : SoftswitchCommand, arg : SoftswitchCommandArgument) {
}

function handle_softswitch_event(source : SoftswitchSource, event : SoftswitchEventContent) {
    dispatch("freeswitch", event);
}

function version() {
    return _version;
}
