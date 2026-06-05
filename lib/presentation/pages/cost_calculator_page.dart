import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CostCalculatorPage extends StatefulWidget {
  const CostCalculatorPage({super.key});

  @override
  State<CostCalculatorPage> createState() => _CostCalculatorPageState();
}

class _CostCalculatorPageState extends State<CostCalculatorPage> {
  final _formKey = GlobalKey<FormState>();
  final _roomPriceController = TextEditingController();
  final _electricPriceController = TextEditingController();
  final _electricUsageController = TextEditingController();
  final _waterPriceController = TextEditingController();
  final _waterUsageController = TextEditingController();
  final _serviceFeeController = TextEditingController();

  double _totalCost = 0;
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

  @override
  void dispose() {
    _roomPriceController.dispose();
    _electricPriceController.dispose();
    _electricUsageController.dispose();
    _waterPriceController.dispose();
    _waterUsageController.dispose();
    _serviceFeeController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (_formKey.currentState?.validate() ?? false) {
      double room = double.tryParse(_roomPriceController.text) ?? 0;
      double ePrice = double.tryParse(_electricPriceController.text) ?? 0;
      double eUsage = double.tryParse(_electricUsageController.text) ?? 0;
      double wPrice = double.tryParse(_waterPriceController.text) ?? 0;
      double wUsage = double.tryParse(_waterUsageController.text) ?? 0;
      double service = double.tryParse(_serviceFeeController.text) ?? 0;

      setState(() {
        _totalCost = room + (ePrice * eUsage) + (wPrice * wUsage) + service;
      });
    } else {
      setState(() => _totalCost = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Máy tính chi phí phòng', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInputCard(
                title: 'Chi phí cơ bản',
                children: [
                  _buildTextField(_roomPriceController, 'Tiền phòng / tháng', Icons.home),
                  const SizedBox(height: 12),
                  _buildTextField(_serviceFeeController, 'Phí dịch vụ (Wifi, rác...)', Icons.miscellaneous_services),
                ],
              ),
              const SizedBox(height: 20),
              _buildInputCard(
                title: 'Tiền Điện',
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_electricPriceController, 'Giá (VNĐ/kWh)', Icons.bolt)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTextField(_electricUsageController, 'Số ký (kWh)', Icons.speed)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildInputCard(
                title: 'Tiền Nước',
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_waterPriceController, 'Giá (VNĐ/m3)', Icons.water_drop)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTextField(_waterUsageController, 'Số khối (m3)', Icons.opacity)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _calculate,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('TÍNH TỔNG CHI PHÍ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 40),
              if (_totalCost > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    children: [
                      const Text('Ước tính tổng chi phí hàng tháng', style: TextStyle(color: Colors.blueGrey)),
                      const SizedBox(height: 8),
                      Text(
                        currencyFormat.format(_totalCost),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: (_) => _calculate(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return 'Không được để trống';
        final number = double.tryParse(text);
        if (number == null) return 'Vui lòng nhập số hợp lệ';
        if (number < 0) return 'Không được nhập số âm';
        return null;
      },
    );
  }
}
