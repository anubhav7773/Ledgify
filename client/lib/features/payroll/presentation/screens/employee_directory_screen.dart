import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../data/repositories/payroll_repository.dart';
import '../domain/models/employee_model.dart';
import 'monthly_payroll_run_screen.dart';

/// Screen listing employee master profiles with quick addition and status controls (Google Stitch UI).
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
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Employee Directory', style: AppTypography.cardHeader),
        backgroundColor: AppColors.surfaceCard,
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
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Employee List',
            onPressed: _loadEmployees,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _employees.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.badge_outlined, size: 48, color: AppColors.primary),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No employee records found.\nTap the button below to add staff.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppColors.standardPadding),
                    itemCount: _employees.length,
                    itemBuilder: (context, index) {
                      final emp = _employees[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.cardBorderRadius),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primaryLight,
                            child: Text(
                              emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : 'E',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                            ),
                          ),
                          title: Text(emp.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                '${emp.employeeCode} • ${emp.designation ?? 'Staff'}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              Text(
                                'Gross Salary: ₹${emp.grossSalary.toStringAsFixed(0)}',
                                style: AppTypography.currencyText.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                              ),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: emp.isActive ? AppColors.debitGreenLight : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              emp.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: emp.isActive ? AppColors.debitGreen : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Employee', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Employee creation form opened.')),
          );
        },
      ),
    );
  }
}
