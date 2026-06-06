library dataconnect_generated;
import 'package:firebase_data_connect/firebase_data_connect.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

part 'create_room.dart';

part 'update_room_status.dart';

part 'list_rooms.dart';

part 'delete_room.dart';







class ExampleConnector {
  
  
  CreateRoomVariablesBuilder createRoom ({required String title, required double price, required String location, required String description, required String status, }) {
    return CreateRoomVariablesBuilder(dataConnect, title: title,price: price,location: location,description: description,status: status,);
  }
  
  
  UpdateRoomStatusVariablesBuilder updateRoomStatus ({required String id, required String status, }) {
    return UpdateRoomStatusVariablesBuilder(dataConnect, id: id,status: status,);
  }
  
  
  ListRoomsVariablesBuilder listRooms () {
    return ListRoomsVariablesBuilder(dataConnect, );
  }
  
  
  DeleteRoomVariablesBuilder deleteRoom ({required String id, }) {
    return DeleteRoomVariablesBuilder(dataConnect, id: id,);
  }
  

  static ConnectorConfig connectorConfig = ConnectorConfig(
    'asia-southeast1',
    'example',
    'roomfinder',
  );

  ExampleConnector({required this.dataConnect});
  static ExampleConnector get instance {
    
    CacheSettings cacheSettings = CacheSettings(
      maxAge: Duration(milliseconds:0),
      storage: CacheStorage.persistent,
    );
    
    return ExampleConnector(
        dataConnect: FirebaseDataConnect.instanceFor(
            connectorConfig: connectorConfig,
            
            cacheSettings: cacheSettings,
            
            sdkType: CallerSDKType.generated));
  }

  FirebaseDataConnect dataConnect;
}
