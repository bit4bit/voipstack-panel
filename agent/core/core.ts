

type SoftswitchSource = string;

type Realm = string;
type UnixTimestamp = number;
type LegNumber = string;
type LegName = string

type Tag = string;
type Tags = Tag[];

type SoftswitchEventContent = Map<string, string | number | null >;
interface SoftswitchEvent {
    source: string
    content: SoftswitchEventContent;
}
type SoftswitchCommand = string
type SoftswitchCommandArgument = string
type ResourceID = string;

class ResourceIDFactory
{
    public static fromString(name: string): ResourceID
    {
        return name.replace(/[^a-zA-Z0-9]/g, "");
    }
}

class CallcenterQueue
{
    id: ResourceID;
    name: string;

    constructor(name: string) {
        this.id = ResourceIDFactory.fromString(name);
        this.name = name;
    }
}

class CallcenterTier
{
    id: ResourceID;

    queue_id: ResourceID;
    // mod_callcenter de freeswitch este concepto
    // esta descoplado, intentamos relacionarlo
    extension_id: ResourceID;

    constructor(queue_id: string, extension_id: string) {
        this.id = ResourceIDFactory.fromString(`${queue_id}@${extension_id}`);
        this.queue_id = ResourceIDFactory.fromString(queue_id);
        this.extension_id = ResourceIDFactory.fromString(extension_id);
    }
}

class Call {
    id: string;
    extension_id: string;

    destination: string;
    direction: string;
    callstate: string;
    realm: string;
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
class Extension {
    id: string;
    name: string;
    realm: Realm;
    expires_at: UnixTimestamp;

    tags: Tags;

    // refrescar con cada cambio de los atributos
    persist_up_to: UnixTimestamp;

    constructor(name: string, realm: string) {
        // formatear identificador, esto es requerido
        // ya que el hash de clojure no permite simbolos
        this.id = `${name}@${realm}`.replace(/[^a-zA-Z0-9]/g, "");
        this.name = name;
        this.realm = realm;
    }

    public static fromPresenceId(data : string): Extension {
        const [name, realm] = data.split("@", 2);
        return new Extension(name, realm);
    }
}

type Extensions = { [key in string]: Extension };
type Calls = { [key in string]: Call };
type CallcenterQueues = any;
type CallcenterTiers = any;

// representa el estado del softswitch
class Softswitch {
    id: string;
    source: SoftswitchSource;
    version: string;
    extensions: Extensions = {};
    calls: Calls = {};
    callcenter_queues: CallcenterQueues = {};
    callcenter_tiers: CallcenterTiers = {};
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
function handle_softswitch_state(source : SoftswitchSource, propertyName : string, propertyValues : any) {
    switch(propertyName) {
        case "callcenter_tiers":
            for(let row of propertyValues["rows"]) {
                const callcenterTier = new CallcenterTier(row.queue, row.agent)

                softswitch.callcenter_tiers[callcenterTier.id] = callcenterTier;
            }
            break;
        case "callcenter_queues":
            for(let row of propertyValues["rows"]) {
                const callcenterQueue = new CallcenterQueue(row.name);
                softswitch.callcenter_queues[callcenterQueue.id] = callcenterQueue;
            }
            break;
        case "registrations":
            for(let row of propertyValues["rows"]) {
                const extension = new Extension(row.reg_user, row.realm);
                
                softswitch.extensions[extension.id] = extension;
            }
            break;
        case "channels":
            if (propertyValues.row_count < 1)
                break;

            const alegs = propertyValues.rows.filter((v: any) => v.call_uuid == "");
            const blegs = propertyValues.rows.filter((v: any) => v.call_uuid != "");


            for(const data of alegs) {
                const call = new Call();
                const ext = Extension.fromPresenceId(data.presence_id);
                const logical_direction: {[key in string]: string} =  {"inbound":"outbound", "outbound":"inbound"};
                // OJO el orden es importante para las pruebas
                // ya que con este orden se codifica el json
                call.id = data.uuid;
                call.extension_id = ext.id;
                call.realm = ext.realm;
                call.direction = logical_direction[data.direction];
                call.destination = data.dest;
                call.callstate = "";
                call.caller_id_name = data.cid_name;
                call.caller_id_number = data.cid_num;
                call.callee_id_name = "";
                call.callee_id_number = "";
                call.created_epoch = data.created_epoch;
                call.tags = [];

                softswitch.calls[data.uuid] = call;
            }
            for (const data of blegs) {
                if (data.call_uuid in softswitch.calls) {
                    softswitch.calls[data.call_uuid].callstate = data.callstate.toLowerCase();
                    softswitch.calls[data.call_uuid].caller_id_number = data.cid_num;
                    softswitch.calls[data.call_uuid].caller_id_name = data.cid_name;
                    softswitch.calls[data.call_uuid].callee_id_number = data.callee_num;
                    softswitch.calls[data.call_uuid].callee_id_name = data.callee_name;
                }
            }
            break;
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

//gestionar ciclo interno
function handle_continue() {
    dispatch("freeswitch", softswitch);
}

function version() {
    return _version;
}
