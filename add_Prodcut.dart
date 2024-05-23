import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProductProvider(),
      child: MaterialApp(
        home: AddProductScreen(),
      ),
    );
  }
}

class AddProductScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Product'),
      ),
      body: AddProductForm(),
    );
  }
}

class AddProductForm extends StatefulWidget {
  @override
  _AddProductFormState createState() => _AddProductFormState();
}

class _AddProductFormState extends State<AddProductForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _shippingAddressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Product Name'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a product name';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Quantity'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a quantity';
                }
                if (int.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Price'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a price';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid price';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _shippingAddressController,
              decoration: InputDecoration(labelText: 'Shipping Address'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a shipping address';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(labelText: 'Description'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            SizedBox(height: 20.0),
            productProvider.imageUrl.isNotEmpty
                ? Column(
                    children: [
                      Image.network(productProvider.imageUrl),
                      TextButton(
                        onPressed: () {
                          productProvider.removeImage();
                        },
                        child: Text('Remove Image'),
                      ),
                    ],
                  )
                : Placeholder(
                    fallbackHeight: 200,
                    fallbackWidth: double.infinity,
                  ),
            SizedBox(height: 20.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => productProvider.getImage(ImageSource.camera),
                  child: Text('Take Photo'),
                ),
                ElevatedButton(
                  onPressed: () => productProvider.getImage(ImageSource.gallery),
                  child: Text('Choose from Gallery'),
                ),
              ],
            ),
            SizedBox(height: 20.0),
            Center(
              child: productProvider.isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState?.validate() ?? false) {
                          productProvider.addProductToFirebase(
                            _nameController.text,
                            int.parse(_quantityController.text),
                            double.parse(_priceController.text),
                            _shippingAddressController.text,
                            _descriptionController.text,
                          );
                        }
                      },
                      child: Text('Add Product'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductProvider with ChangeNotifier {
  String _imageUrl = '';
  bool _isLoading = false;

  String get imageUrl => _imageUrl;
  bool get isLoading => _isLoading;

  Future<void> getImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedImage = await picker.getImage(source: source);

    if (pickedImage != null) {
      _isLoading = true;
      notifyListeners();

      try {
        Reference ref = FirebaseStorage.instance
            .ref()
            .child('product_images')
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(File(pickedImage.path));
        String downloadUrl = await ref.getDownloadURL();

        _imageUrl = downloadUrl;
      } catch (e) {
        
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void removeImage() {
    _imageUrl = '';
    notifyListeners();
  }

  void addProductToFirebase(String name, int quantity, double price, String shippingAddress, String description) async {
    _isLoading = true;
    notifyListeners();

    DatabaseReference productsRef = FirebaseDatabase.instance.reference().child('products');
    String productId = productsRef.push().key ?? '';

    Product product = Product(
      id: productId,
      name: name,
      quantity: quantity,
      price: price,
      shippingAddress: shippingAddress,
      description: description,
      imageUrl: _imageUrl,
    );

    try {
      await productsRef.child(product.id).set(product.toJson());
    } catch (error) {

    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

class Product {
  final String id;
  final String name;
  final int quantity;
  final double price;
  final String shippingAddress;
  final String description;
  final String imageUrl;

  Product({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    required this.shippingAddress,
    required this.description,
    required this.imageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'price': price,
      'shippingAddress': shippingAddress,
      'description': description,
      'imageUrl': imageUrl,
    };
  }
}


