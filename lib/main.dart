import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tienda Flutter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ProductListPage(),
    );
  }
}

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  List<dynamic> products = [];
  bool isLoading = true;

  final TextEditingController codigoController = TextEditingController();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController precioController = TextEditingController();
  final TextEditingController cantidadController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchProducts();
  }

  Future<void> fetchProducts() async {
    const String apiUrl = 'http://10.0.2.2:8080/api/productos'; // Cambiado a final
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            products = json.decode(response.body);
            isLoading = false;
          });
          checkLowStock();
        }
      } else {
        throw Exception('Error al cargar productos: ${response.statusCode}');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void checkLowStock() {
    final messenger = ScaffoldMessenger.of(context);
    for (var product in products) {
      double cantidad = (product['cantidad'] ?? 0).toDouble();
      double cantidadInicial = (product['cantidad_inicial'] ?? 1).toDouble();

      if (cantidad <= 0.1 * cantidadInicial) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'El producto "${product['nombre']}" está a punto de agotarse.',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> deleteProduct(int id) async {
    final String apiUrl = 'http://10.0.2.2:8080/api/productos/$id'; // Cambiado a final
    final messenger = ScaffoldMessenger.of(context);
    try {
      final response = await http.delete(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            products.removeWhere((product) => product['codigo'] == id);
          });
          messenger.showSnackBar(
            const SnackBar(content: Text('Producto eliminado correctamente.')),
          );
          checkLowStock();
        }
      } else {
        throw Exception('Error al eliminar producto: ${response.statusCode}');
      }
    } catch (error) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Error al eliminar el producto.')),
      );
    }
  }

  Future<void> addOrUpdateProduct() async {
    const String apiUrl = 'http://10.0.2.2:8080/api/productos'; // Cambiado a final
    final messenger = ScaffoldMessenger.of(context);
    try {
      final product = {
        "codigo": int.tryParse(codigoController.text) ?? 0,
        "nombre": nombreController.text,
        "precio": double.tryParse(precioController.text) ?? 0.0,
        "cantidad": int.tryParse(cantidadController.text) ?? 0,
        "cantidad_inicial": int.tryParse(cantidadController.text) ?? 0,
      };

      if ((product['nombre'] as String?)?.isEmpty ?? true) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Todos los campos son obligatorios y deben tener valores válidos.')),
        );
        return;
      }

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(product),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        fetchProducts();
        messenger.showSnackBar(
          const SnackBar(content: Text('Producto agregado/actualizado correctamente.')),
        );
        clearFormFields();
      } else {
        throw Exception('Error al agregar/actualizar producto: ${response.statusCode}');
      }
    } catch (error) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Error al agregar/actualizar el producto.')),
      );
    }
  }

  void clearFormFields() {
    codigoController.clear();
    nombreController.clear();
    precioController.clear();
    cantidadController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tienda de Productos'),
      ),
      body: Column(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 20.0,
                  headingRowColor: WidgetStateColor.resolveWith((states) => Colors.blue[300]!),
                  columns: const [
                    DataColumn(label: Text('Código')),
                    DataColumn(label: Text('Nombre')),
                    DataColumn(label: Text('Precio')),
                    DataColumn(label: Text('Cantidad')),
                    DataColumn(label: Text('Acciones')),
                  ],
                  rows: products.map((product) {
                    final cantidad = (product['cantidad'] ?? 0).toDouble();
                    final cantidadInicial = (product['cantidad_inicial'] ?? 1).toDouble();
                    final precio = (product['precio'] ?? 0).toDouble();
                    return DataRow(cells: [
                      DataCell(Text(product['codigo'].toString())),
                      DataCell(Text(product['nombre'])),
                      DataCell(Text('\$${precio.toStringAsFixed(2)}')),
                      DataCell(
                        Text(
                          cantidad.toStringAsFixed(0),
                          style: TextStyle(
                            color: cantidad <= 0.1 * cantidadInicial ? Colors.red : Colors.black,
                          ),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Confirmar'),
                                  content: const Text(
                                      '¿Estás seguro de que deseas eliminar este producto?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        deleteProduct(product['codigo']);
                                      },
                                      child: const Text('Eliminar'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Agregar/Actualizar Producto',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: codigoController,
                        decoration: const InputDecoration(labelText: 'Código (opcional)'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: nombreController,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: precioController,
                        decoration: const InputDecoration(labelText: 'Precio'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: cantidadController,
                        decoration: const InputDecoration(labelText: 'Cantidad'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: addOrUpdateProduct,
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
