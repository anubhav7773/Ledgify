import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/color_tokens.dart';
import 'package:ledgify/features/reports/domain/models/cash_flow_forecast_point.dart';

/// Interactive 30-day forward-looking cash flow forecast line chart using fl_chart.
class CashFlowForecastChart extends StatelessWidget {
  final List<CashFlowForecastPoint> forecastPoints;

  const CashFlowForecastChart({
    super.key,
    required this.forecastPoints,
  });

  @override
  Widget build(BuildContext context) {
    if (forecastPoints.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('Insufficient historical velocity for 30-day forecast.')),
      );
    }

    final spots = forecastPoints.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.projectedBalance);
    }).toList();

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LedgifyColors.cardBorderRadius),
        side: const BorderSide(color: LedgifyColors.surfaceVariant),
      ),
      color: LedgifyColors.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('30-Day Predictive Cash Runway', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('अनुमानित 30-दिवसीय रोकड़ प्रवाह', style: TextStyle(fontSize: 11, color: LedgifyColors.secondarySlate)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: LedgifyColors.debitGreenBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('AI Velocity', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: LedgifyColors.debitGreen)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: ((maxY - minY) / 4).clamp(1000.0, 500000.0),
                    getDrawingHorizontalLine: (value) => const FlLine(color: LedgifyColors.surfaceVariant, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 7,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < forecastPoints.length) {
                            final d = forecastPoints[idx].date;
                            return Text('${d.day}/${d.month}', style: const TextStyle(fontSize: 10, color: LedgifyColors.secondarySlate));
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (forecastPoints.length - 1).toDouble(),
                  minY: minY * 0.9,
                  maxY: maxY * 1.1,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => LedgifyColors.primaryBlue,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final p = forecastPoints[spot.x.toInt()];
                          return LineTooltipItem(
                            '${p.date.day}/${p.date.month}\nBal: ₹${p.projectedBalance.toStringAsFixed(0)}\nIn: +₹${p.projectedInflow.toStringAsFixed(0)}\nOut: -₹${p.projectedOutflow.toStringAsFixed(0)}',
                            const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: LedgifyColors.primaryBlue,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: LedgifyColors.primaryBlue.withOpacity(0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
