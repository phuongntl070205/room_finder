part of 'generated.dart';

class CreateRoomVariablesBuilder {
  String title;
  double price;
  String location;
  String description;
  String status;

  final FirebaseDataConnect _dataConnect;
  CreateRoomVariablesBuilder(this._dataConnect, {required  this.title,required  this.price,required  this.location,required  this.description,required  this.status,});
  Deserializer<CreateRoomData> dataDeserializer = (dynamic json)  => CreateRoomData.fromJson(jsonDecode(json));
  Serializer<CreateRoomVariables> varsSerializer = (CreateRoomVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<CreateRoomData, CreateRoomVariables>> execute() {
    return ref().execute();
  }

  MutationRef<CreateRoomData, CreateRoomVariables> ref() {
    CreateRoomVariables vars= CreateRoomVariables(title: title,price: price,location: location,description: description,status: status,);
    return _dataConnect.mutation("CreateRoom", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class CreateRoomRoomInsert {
  final String id;
  CreateRoomRoomInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateRoomRoomInsert otherTyped = other as CreateRoomRoomInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  CreateRoomRoomInsert({
    required this.id,
  });
}

@immutable
class CreateRoomData {
  final CreateRoomRoomInsert room_insert;
  CreateRoomData.fromJson(dynamic json):
  
  room_insert = CreateRoomRoomInsert.fromJson(json['room_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateRoomData otherTyped = other as CreateRoomData;
    return room_insert == otherTyped.room_insert;
    
  }
  @override
  int get hashCode => room_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['room_insert'] = room_insert.toJson();
    return json;
  }

  CreateRoomData({
    required this.room_insert,
  });
}

@immutable
class CreateRoomVariables {
  final String title;
  final double price;
  final String location;
  final String description;
  final String status;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  CreateRoomVariables.fromJson(Map<String, dynamic> json):
  
  title = nativeFromJson<String>(json['title']),
  price = nativeFromJson<double>(json['price']),
  location = nativeFromJson<String>(json['location']),
  description = nativeFromJson<String>(json['description']),
  status = nativeFromJson<String>(json['status']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateRoomVariables otherTyped = other as CreateRoomVariables;
    return title == otherTyped.title && 
    price == otherTyped.price && 
    location == otherTyped.location && 
    description == otherTyped.description && 
    status == otherTyped.status;
    
  }
  @override
  int get hashCode => Object.hashAll([title.hashCode, price.hashCode, location.hashCode, description.hashCode, status.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['title'] = nativeToJson<String>(title);
    json['price'] = nativeToJson<double>(price);
    json['location'] = nativeToJson<String>(location);
    json['description'] = nativeToJson<String>(description);
    json['status'] = nativeToJson<String>(status);
    return json;
  }

  CreateRoomVariables({
    required this.title,
    required this.price,
    required this.location,
    required this.description,
    required this.status,
  });
}

