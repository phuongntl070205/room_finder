part of 'generated.dart';

class ListRoomsVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  ListRoomsVariablesBuilder(this._dataConnect, );
  Deserializer<ListRoomsData> dataDeserializer = (dynamic json)  => ListRoomsData.fromJson(jsonDecode(json));
  
  Future<QueryResult<ListRoomsData, void>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<ListRoomsData, void> ref() {
    
    return _dataConnect.query("ListRooms", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class ListRoomsRooms {
  final String title;
  final double price;
  final String location;
  final ListRoomsRoomsLandlord landlord;
  ListRoomsRooms.fromJson(dynamic json):
  
  title = nativeFromJson<String>(json['title']),
  price = nativeFromJson<double>(json['price']),
  location = nativeFromJson<String>(json['location']),
  landlord = ListRoomsRoomsLandlord.fromJson(json['landlord']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListRoomsRooms otherTyped = other as ListRoomsRooms;
    return title == otherTyped.title && 
    price == otherTyped.price && 
    location == otherTyped.location && 
    landlord == otherTyped.landlord;
    
  }
  @override
  int get hashCode => Object.hashAll([title.hashCode, price.hashCode, location.hashCode, landlord.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['title'] = nativeToJson<String>(title);
    json['price'] = nativeToJson<double>(price);
    json['location'] = nativeToJson<String>(location);
    json['landlord'] = landlord.toJson();
    return json;
  }

  ListRoomsRooms({
    required this.title,
    required this.price,
    required this.location,
    required this.landlord,
  });
}

@immutable
class ListRoomsRoomsLandlord {
  final String name;
  ListRoomsRoomsLandlord.fromJson(dynamic json):
  
  name = nativeFromJson<String>(json['name']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListRoomsRoomsLandlord otherTyped = other as ListRoomsRoomsLandlord;
    return name == otherTyped.name;
    
  }
  @override
  int get hashCode => name.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['name'] = nativeToJson<String>(name);
    return json;
  }

  ListRoomsRoomsLandlord({
    required this.name,
  });
}

@immutable
class ListRoomsData {
  final List<ListRoomsRooms> rooms;
  ListRoomsData.fromJson(dynamic json):
  
  rooms = (json['rooms'] as List<dynamic>)
        .map((e) => ListRoomsRooms.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListRoomsData otherTyped = other as ListRoomsData;
    return rooms == otherTyped.rooms;
    
  }
  @override
  int get hashCode => rooms.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['rooms'] = rooms.map((e) => e.toJson()).toList();
    return json;
  }

  ListRoomsData({
    required this.rooms,
  });
}

