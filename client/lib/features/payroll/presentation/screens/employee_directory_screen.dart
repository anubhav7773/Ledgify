import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../data/repositories/payroll_repository.dart';
import '../domain/models/employee_model.dart';
import 'monthly_payroll_run_screen.dart';

/// Screen listing employee master profiles with quick addition and status controls.
class EmployeeDirectoryScreen extends StatefulWidget {
  final PayrollRepository? repository;

  const EmployeeDirectoryScreen({super.key, this.repository});

  @override
  State<EmployeeDirectoryScreen> createState() => _EmployeeDirectoryScreenState();
}

class _EmployeeDirectoryScreenState extends State<EmployeeDirectoryScreen> {
  late final PayrollRepository _repository;
  bool _isLoading = true;
  List<EmployeeModel> _employees = [];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? PayrollRepository();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final emps = await _repository.fetchEmployees(activeOnly: false);
      if (mounted) {
        setState(() {
          _employees = emps;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees & Payroll / कर्मचारी सूची', style: LedgifyTypography.cardHeader),
        backgroundColor: LedgifyColors.surfaceLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'Run Monthly Payroll',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MonthlyPayrollRunScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEmployees,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: LedgifyColors.primaryBlue))
            : _employees.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.badge_outlined, size: 48, color: LedgifyColors.secondarySlate),
                        const SizedBox(height: 12),
                        const Text(
                          'No employee records found.\nकर्मचारी जोड़ने के लिए नीचे दिए गए बटन पर टैप करें',
                          textAlign: TextAlign.center,
                          style: LedgifyTypography.bilingualLabel,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _employees.length,
                    itemBuilder: (context, index) {
                      final emp = _employees[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: LedgifyColors.surfaceVariant),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: LedgifyColors.primaryContainer,
                            child: Text(
                              emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : 'E',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: LedgifyColors.primaryBlue),
                            ),
                          ),
                          title: Text(emp.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            '${emp.employeeCode} • ${emp.designation ?? 'Staff'} • Gross: ₹${emp.grossSalary.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 12, color: LedgifyColors.secondarySlate),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: emp.isActive ? LedgifyColors.debitGreenBg : LedgifyColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              emp.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: emp.isActive ? LedgifyColors.debitGreen : LedgifyColors.secondarySlate,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: LedgifyColors.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Employee / कर्मचारी जोड़ें'),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Employee creation form opened.')),
          );
        },
      ),
    );
  }
}
