import 'package:flutter_bloc/flutter_bloc.dart';
import 'report_definition.dart';
import 'reports_repository.dart';

sealed class ReportsEvent {}
/// Selects a report and date range; the table then pages rows from the API.
class ReportsRequested extends ReportsEvent {
  ReportsRequested(this.definition, {this.from, this.to});
  final ReportDefinition definition;
  final String? from, to;
}
class ReportsState {
  const ReportsState({this.definition, this.invalidDates = false, this.from, this.to});
  final ReportDefinition? definition;
  final bool invalidDates;
  final String? from, to;
}
class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  ReportsBloc(this.repository, this.corporateId) : super(const ReportsState()) {
    on<ReportsRequested>((event, emit) {
      final from = event.definition.dated ? event.from : null;
      final to = event.definition.dated ? event.to : null;
      emit(ReportsState(definition: event.definition, from: from, to: to,
        invalidDates: from != null && to != null && from.compareTo(to) > 0));
    });
  }
  final ReportsRepository repository;
  final String corporateId;
}
