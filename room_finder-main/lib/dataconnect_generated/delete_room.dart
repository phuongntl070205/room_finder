part of 'generated.dart';

class DeleteRoomVariablesBuilder {
  String id;

  final FirebaseDataConnect _dataConnect;
  DeleteRoomVariablesBuilder(this._dataConnect, {required  this.id,});
  Deserializer<DeleteRoomData> dataDeserializer = (dynamic json)  => DeleteRoomData.fromJson(jsonDecode(json));
  Serializer<DeleteRoomVariables> varsSerializer = (DeleteRoomVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<DeleteRoomData, DeleteRoomVariables>> execute() {
    return ref().execute();
  }

  MutationRef<DeleteRoomData, DeleteRoomVariables> ref() {
    DeleteRoomVariables vars= DeleteRoomVariables(id: id,);
    return _dataConnect.mutation("DeleteRoom", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class DeleteRoomRoomDelete {
  final String id;
  DeleteRoomRoomDelete.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteRoomRoomDelete otherTyped = other as DeleteRoomRoomDelete;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  DeleteRoomRoomDelete({
    required this.id,
  });
}

@immutable
class DeleteRoomData {
  final DeleteRoomRoomDelete? room_delete;
  DeleteRoomData.fromJson(dynamic json):
  
  room_delete = json['room_delete'] == null ? null : DeleteRoomRoomDelete.fromJson(json['room_delete']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteRoomData otherTyped = other as DeleteRoomData;
    return room_delete == otherTyped.room_delete;
    
  }
  @override
  int get hashCode => room_delete.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    if (room_delete != null) {
      json['room_delete'] = room_delete!.toJson();
    }
    return json;
  }

  DeleteRoomData({
    this.room_delete,
  });
}

@immutable
class DeleteRoomVariables {
  final String id;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  DeleteRoomVariables.fromJson(Map<String, dynamic> json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final DeleteRoomVariables otherTyped = other as DeleteRoomVariables;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  DeleteRoomVariables({
    required this.id,
  });
}

