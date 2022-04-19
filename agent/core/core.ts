

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
    extension_id: string;

    destination: string;
    direction: string;
    callstate: string;
    caller_id_name: LegName;
    caller_id_number: LegNumber;
    callee_id_name: LegName;
    callee_id_number: LegNumber;
    created_epoch: UnixTimestamp;
    answered_epoch: UnixTimestamp;
    hangup_epoch: UnixTimestamp;

    // etiquetamos la llamada, ejemplos: inbound,
    // callcenter-queue:7000@pruebas.org
    tags: Tags;
    // al superar esta fecha se elimina del cache
    persist_up_to: UnixTimestamp;
}

// representa el registro sip actual de una extension
interface Extension {
    id: string;
    name: string;
    realm: Realm;
    expires_at: UnixTimestamp;

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
    calls: Call[];
}

interface SoftswitchState {
    source: string
}

interface FreeswitchState extends SoftswitchState {
    extensions: Extension[];
    calls: Call[];
}

interface AsteriskState {
}

var softswitch = new Softswitch();
var _version = 333;

//emitir evento a plataforma
declare  function dispatch(source : SoftswitchSource, event : any) : void;

//gestionar nueva estado del softswitch
function handle_softswitch_state(source : SoftswitchSource, state : FreeswitchState | AsteriskState) {
    if(source == "freeswitch") {
        const current = state as FreeswitchState;
        softswitch.extensions = current.extensions;
        softswitch.calls = current.calls;
    }
}

//gestionar accion iniciada desde la plataforma
function handle_panel_command(cmd : SoftswitchCommand, arg : SoftswitchCommandArgument) {
}

function handle_softswitch_event(source : SoftswitchSource, event : any) {
    //TODO(bit4bit) solo para pruebas
    if(source == "platform" && event.action == "refresh-state") {
        dispatch("freeswitch", softswitch);
    } else {
        dispatch("freeswitch", event);
    }
}

function version() {
    return _version;
}
