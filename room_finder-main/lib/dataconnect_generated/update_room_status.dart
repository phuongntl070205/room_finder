part of 'generated.dart';

class UpdateRoomStatusVariablesBuilder {
  String id;
  String status;

  final FirebaseDataConnect _dataConnect;
  UpdateRoomStatusVariablesBuilder(this._dataConnect, {required  this.id,required  this.status,});
  Deserializer<UpdateRoomStatusData> dataDeserializer = (dynamic json)  => UpdateRoomStatusData.fromJson(jsonDecode(json));
  Serializer<UpdateRoomStatusVariables> varsSerializer = (UpdateRoomStatusVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<UpdateRoomStatusData, UpdateRoomStatusVariables>> execute() {
    return ref().execute();
  }

  MutationRef<UpdateRoomStatusData, UpdateRoomStatusVariables> ref() {
    UpdateRoomStatusVariables vars= UpdateRoomStatusVariables(id: id,status: status,);
    return _dataConnect.mutation("UpdateRoomStatus", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class UpdateRoomStatusRoomUpdate {
  final String id;
  UpdateRoomStatusRoomUpdate.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateRoomStatusRoomUpdate otherTyped = other as UpdateRoomStatusRoomUpdate;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  UpdateRoomStatusRoomUpdate({
    required this.id,
  });
}

@immutable
class UpdateRoomStatusData {
  final UpdateRoomStatusRoomUpdate? room_update;
  UpdateRoomStatusData.fromJson(dynamic json):
  
  room_update = json['room_update'] == null ? null : UpdateRoomStatusRoomUpdate.fromJson(json['room_update']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateRoomStatusData otherTyped = other as UpdateRoomStatusData;
    return room_update == otherTyped.room_update;
    
  }
  @override
  int get hashCode => room_update.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (room_update != null) {
      json['room_update'] = room_update!.toJson();
    }
    return json;
  }

  UpdateRoomStatusData({
    this.room_update,
  });
}

@immutable
class UpdateRoomStatusVariables {
  final String id;
  final String status;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  UpdateRoomStatusVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']),
  status = nativeFromJson<String>(json['status']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final UpdateRoomStatusVariables otherTyped = other as UpdateRoomStatusVariables;
    return id == otherTyped.id && 
    status == otherTyped.status;
    
  }
  @override
  int get hashCode => Object.hashAll([id.hashCode, status.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['status'] = nativeToJson<String>(status);
    return json;
  }

  UpdateRoomStatusVariables({
    required this.id,
    required this.status,
  });
}

