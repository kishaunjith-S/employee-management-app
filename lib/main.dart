import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class Employee {
  final int id;
  final String name;
  final double salary;
  final String role;
  Employee({
    required this.id,
    required this.name,
    required this.salary,
    required this.role,
  });
  factory Employee.fromJson(Map<String, dynamic> json) {
    try {
      final id = int.parse(json['id']?.toString() ?? '0');
      final name = json['name']?.toString() ?? 'Unknown';
      final salaryString = json['salary']?.toString() ?? '0.0';
      final salary = double.parse(salaryString);
      final role = json['role']?.toString() ?? 'Unknown';
      return Employee(
        id: id,
        name: name,
        salary: salary,
        role: role,
      );
    } catch (e) {
      throw FormatException('Error parsing employee data: $e');
    }
  }
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'salary': salary,
      'role': role,
    };
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Employee Management',
      theme: ThemeData(
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.blue,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const EmployeeListScreen(),
    );
  }
}

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({Key? key}) : super(key: key);
  @override
  _EmployeeListScreenState createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  List<Employee> employees = [];
  final _nameController = TextEditingController();
  final _salaryController = TextEditingController();
  final _roleController = TextEditingController();
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int? _editingId;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _debounceTimer;
  final String baseUrl =
      'http://192.168.137.1:3000/api/employees'; // Replace with your machine's IP if needed
  @override
  void initState() {
    super.initState();
    _fetchEmployees();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _salaryController.dispose();
    _roleController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      _fetchEmployees();
    });
  }

  Future<void> _fetchEmployees() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    try {
      final query = _searchController.text.trim();
      final url = query.isEmpty
          ? baseUrl
          : '$baseUrl?namePrefix=${Uri.encodeQueryComponent(query)}';
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception(
              'Request timed out. Please check your network connection.');
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          employees = data.map((json) {
            try {
              return Employee.fromJson(json as Map<String, dynamic>);
            } catch (e) {
              rethrow;
            }
          }).toList();
        });
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to fetch employees: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Error fetching employees: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addEmployee(Employee employee) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(employee.toJson()),
      );
      if (response.statusCode == 201) {
        await _fetchEmployees();
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to add employee: ${response.statusCode}';
        });
        _showError(_errorMessage);
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Error adding employee: $e';
      });
      _showError(_errorMessage);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateEmployee(int id, Employee employee) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(employee.toJson()),
      );
      if (response.statusCode == 200) {
        await _fetchEmployees();
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to update employee: ${response.statusCode}';
        });
        _showError(_errorMessage);
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Error updating employee: $e';
      });
      _showError(_errorMessage);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteEmployee(int id) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    try {
      final response = await http.delete(Uri.parse('$baseUrl/$id'));
      if (response.statusCode == 204) {
        await _fetchEmployees();
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to delete employee: ${response.statusCode}';
        });
        _showError(_errorMessage);
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Error deleting employee: $e';
      });
      _showError(_errorMessage);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showEmployeeDialog({Employee? employee}) {
    if (employee != null) {
      _nameController.text = employee.name;
      _salaryController.text = employee.salary.toString();
      _roleController.text = employee.role;
      _editingId = employee.id;
    } else {
      _nameController.clear();
      _salaryController.clear();
      _roleController.clear();
      _editingId = null;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          employee == null ? 'Add Employee' : 'Edit Employee',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) => value!.isEmpty ? 'Enter a name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _salaryController,
                  decoration: const InputDecoration(
                    labelText: 'Salary',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value!.isEmpty) return 'Enter a salary';
                    final salary = double.tryParse(value);
                    if (salary == null || salary <= 0) {
                      return 'Enter a valid positive salary';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _roleController,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.work),
                  ),
                  validator: (value) => value!.isEmpty ? 'Enter a role' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final employee = Employee(
                  id: _editingId ?? 0,
                  name: _nameController.text,
                  salary: double.parse(_salaryController.text),
                  role: _roleController.text,
                );
                if (_editingId == null) {
                  _addEmployee(employee);
                } else {
                  _updateEmployee(_editingId!, employee);
                }
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _searchController.clear();
              _fetchEmployees();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name prefix...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _hasError
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage,
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.red[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                _searchController.clear();
                                _fetchEmployees();
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : employees.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchController.text.isEmpty
                                      ? 'No employees found'
                                      : 'No employees found with name starting with "${_searchController.text}"',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            itemCount: employees.length,
                            itemBuilder: (context, index) {
                              final employee = employees[index];
                              return AnimatedOpacity(
                                opacity: 1.0,
                                duration: const Duration(milliseconds: 300),
                                child: Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16.0),
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue[100],
                                      child: Text(
                                        employee.name[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      'NAME  : ${employee.name}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        'ROLE      : ${employee.role} \nSALARY : \$${employee.salary.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.blue,
                                          ),
                                          onPressed: () => _showEmployeeDialog(
                                              employee: employee),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              _deleteEmployee(employee.id),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEmployeeDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
