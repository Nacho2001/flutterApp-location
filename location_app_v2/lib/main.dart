import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Función principal
void main() {
  runApp(const MainApp());
}

// Widget principal
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Despliega el widget con estado
      home: CurrentLocationMap()
    );
  }
}

// Declara widget con estado de ubicación actual
// ignore: use_key_in_widget_constructors
class CurrentLocationMap extends StatefulWidget {
  @override
  // ignore: library_private_types_in_public_api
  _CurrentLocationMapState createState() => _CurrentLocationMapState();
}

// Estado de Widget anterior
class _CurrentLocationMapState extends State<CurrentLocationMap> {
  // Controlador google Maps
  late GoogleMapController _controller;

  // Valor de inicial de ubicación de usuario en latitud y longitud (coordenadas)
  LatLng _currentPosition = const LatLng(0.0, 0.0);

  // Valor inicial de pin secundario
  LatLng _pinPosition = const LatLng(0.0, 0.0);

  // Posición de camara
  final CameraPosition _initialCameraPosition = 
  const CameraPosition(
    // ubicación inicial
    target: LatLng(0.0,0.0),
    // Zoom de mapa
    zoom: 14.0
  );

  /// Marcador de ubicaciones, este se actualizará con los cambios de ubicación
  final Map<MarkerId, Marker> _markers = {};

  // Declara _positionStream para recibir actualizaciones de ubicacion en tiempo real
  late Stream<Position> _positionStream;

  // Estado del rango de distancia, si se encuentra a más de 15 metros es false
  bool _inRange = false;

  @override
  // Inicia el estado y activa la función para obtener la ubicación
  void initState(){
    super.initState();
    _getCurrentLocation();
  }

  // Comprueba los permisos de ubicación y obtiene la ubicación del usuario
  Future<void> _getCurrentLocation() async {
    // Variable: Guarda el estado del servicio, si es true, el servicio esta activado
    bool serviceStatus;
    // Variable: Permisos de ubicación (Android)
    LocationPermission permission;

    // Compruba si la ubicación está activada, usando geolator
    serviceStatus = await Geolocator.isLocationServiceEnabled();
    /**
     * Si la ubicación no esta activada, no continua con la función,
     * ya que no podrá obtener la posición del usuario
     */
    if(!serviceStatus){
      return;
    }

    // Compruba si tiene permiso para acceder a la aplicación
    permission = await Geolocator.checkPermission();
    // Si el permiso esta denegado, lo solicita
    if(permission == LocationPermission.denied){
      permission = await Geolocator.requestPermission();
      // Comprueba nuevamente si el permiso fue denegado
      if(permission == LocationPermission.denied){
        // Si la solicitud fue rechazada, no continua con la función
        return;
      }
    }

    // Tampoco continua si los permisos fueron denegados permantenemente
    if(permission == LocationPermission.deniedForever){
      return;
    }

    _positionStream = Geolocator.getPositionStream(
      // Configuración de Geolocator
      locationSettings: const LocationSettings(
        // Ajusta la precisión de la ubicación, high es la ubicación más precisa
        accuracy: LocationAccuracy.high,
        // Actualiza la ubicación cada 2 metros
        distanceFilter: 2
      )
    );

    /// Escucha cambios en la ubicación y lo envia al estado con las coordenadas
    /// y actualiza el pin
    _positionStream.listen((Position position) {
      setState((){
        // Guarda las coordenadas en el state
        _currentPosition = LatLng(position.latitude, position.longitude);

        // Actualizar camara y marcador en mapa
        _updateMap(_currentPosition);
      });
    });
  }

  // Actualiza la cámara y el pin con la ubicación actual (lo que se ve en el mapa)
  void _updateMap(LatLng position){
    // ID del pin
    const pinId = MarkerId("ubicacion_actual");
    // Declara el pin o marcador nuevo que señala la ubicación
    final pin = Marker(
      // Id declarado previamente
      markerId: pinId,
      // Nueva ubicación
      position: position,
      // Descripción del pin
      infoWindow: const InfoWindow(title: "Ubicación previa"),
      // Icono del pin (se eligió con un color verde)
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
    );

    /// Guarda el pin con la ubicación
    _markers[pinId] = pin;

    // Actualizar camara del mapa para enfocar la posición nueva
    _controller.animateCamera(
      CameraUpdate.newLatLng(position)
    );
  }

  // Crear pin al tocar pantalla y obtener la distancia
  void _newPin(LatLng tappedPosition){
    // Actualiza posición del pin secundario
    _pinPosition = tappedPosition;

    setState(() {
      // Borrar punto anterior marcado
      _markers.clear();

      // Guarda id del pin marcado
      final pinId = MarkerId("pin_${_markers.length}");
      // Crea el pin nuevo con los datos:
      final pin = Marker(
        // pin ID
        markerId: pinId,
        // Coordendas de ubicación
        position: tappedPosition,
        // Cartel informativo
        infoWindow: const InfoWindow(title: "Punto seleccionado"),
        // Icono y color del pin (amarillo)
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow) 
      );

      // Guarda el pin nuevo en colección
      _markers[pinId] = pin;
    });

    // Calcula distancia entre punto señalado y ubicación actual
    double distance = _calculateDistance();

    // Actualiza el estado del boton flotante, si la distancia es menor a 15 metros
    _inRange = distance <= 15;

    // Muestra dialogo con distancia entre ambos puntos
    _distanceDialog();
  }

  double _calculateDistance(){
    double distance = Geolocator.distanceBetween(
      // Latitud de posición actual
      _currentPosition.latitude, 
      // Longitud de posición actual
      _currentPosition.longitude,
      // Latitud de punto señalado 
      _pinPosition.latitude, 
      // Longitud de punto señalado
      _pinPosition.longitude
    );
    // Calculada la distancia, devuelve el numero obtenido
    return distance;
  }
  // Muestra dialogo con distacia entre ambos puntos al marcar un pin nuevo (función)
  void _distanceDialog(){
    // Calcula la distancia ente ubicación y el pin (ambos guardados en el state)
    double distance = _calculateDistance();
    // Widget de dialogo que se despliega
    showDialog(
      context: context, 
      builder: (context){
        return AlertDialog(
          // Titulo de la alerta
          title: const Text("Distancia entre puntos"),
          // Texto del contenido
          content: Text("Distancia: ${distance.toStringAsFixed(1)} metros"),
          // Posibles acciones: Solo pulsar el botón OK
          actions: [
            TextButton(
              child: const Text("Ok"),
              onPressed: () => Navigator.of(context).pop())
          ]
        );
      }
    );
  }

  
  // Crea vista de usuario
  @override
  Widget build(BuildContext context){
    return Scaffold(
      // AppBar con titulo
      appBar: AppBar(
        title: const Center(child: Text("Fichador")),
        backgroundColor: Colors.green.shade300,
      ),
      // En el cuerpo, mapa de Google Maps que muestre la ubicación
      body: Stack(
        children: [
          GoogleMap(
            // Posición inicial de la camara
            initialCameraPosition: _initialCameraPosition,
            // Cuando inicia el mapa, declara el controlador
            onMapCreated: (GoogleMapController mapsController){
              _controller = mapsController;
            },
            onTap: _newPin,
            // Activa el boton para obtener la ubicación
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: Set<Marker>.of(_markers.values),
          ),
          Positioned(
            bottom: 25,
            left: 20,
            child: FloatingActionButton(
              onPressed: (){
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _inRange ? "Fichaje correcto" : "No se encuentra cerca del punto de fichaje"
                    ),
                  )
                );
              },
              backgroundColor: _inRange ? Colors.green : Colors.red,
              child: Icon(_inRange ? Icons.check : Icons.warning)
            )
          )
        ],
      )
    );
  }
}