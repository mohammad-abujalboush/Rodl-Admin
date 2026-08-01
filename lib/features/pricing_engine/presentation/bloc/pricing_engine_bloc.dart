import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import 'package:roadside_service/features/pricing_engine/data/models/pricing_rule_model.dart';
import '../../../../core/api/dio_client.dart';

// --- EVENTS ---
abstract class PricingEngineEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchPricingRules extends PricingEngineEvent {}

class SavePricingRule extends PricingEngineEvent {
  final PricingRuleModel rule;
  final bool isNew;
  SavePricingRule({required this.rule, required this.isNew});
  @override
  List<Object> get props => [rule, isNew];
}

// --- STATES ---
abstract class PricingEngineState extends Equatable {
  @override
  List<Object> get props => [];
}

class PricingLoading extends PricingEngineState {}

class PricingLoaded extends PricingEngineState {
  final List<PricingRuleModel> rules;
  PricingLoaded(this.rules);
  @override
  List<Object> get props => [rules];
}

class PricingError extends PricingEngineState {
  final String message;
  PricingError(this.message);
  @override
  List<Object> get props => [message];
}

class PricingActionSuccess extends PricingEngineState {
  final String message;
  PricingActionSuccess(this.message);
  @override
  List<Object> get props => [message];
}

// --- BLOC ---
class PricingEngineBloc extends Bloc<PricingEngineEvent, PricingEngineState> {
  final DioClient dioClient;

  PricingEngineBloc({required this.dioClient}) : super(PricingLoading()) {
    on<FetchPricingRules>((event, emit) async {
      emit(PricingLoading());
      try {
        final response = await dioClient.dio.get('/api/admin/pricing-rules');
        final rules = (response.data as List)
            .map((json) => PricingRuleModel.fromJson(json))
            .toList();
        emit(PricingLoaded(rules));
      } catch (e) {
        emit(PricingError('Failed to fetch pricing architecture.'));
      }
    });

    on<SavePricingRule>((event, emit) async {
      try {
        if (event.isNew) {
          await dioClient.dio.post(
            '/api/admin/pricing-rules',
            data: event.rule.toJson(),
          );
          emit(PricingActionSuccess('New Pricing Matrix compiled and stored.'));
        } else {
          await dioClient.dio.put(
            '/api/admin/pricing-rules/${event.rule.serviceType}',
            data: event.rule.toJson(),
          );
          emit(
            PricingActionSuccess('Pricing Matrix successfully overwritten.'),
          );
        }
        add(FetchPricingRules());
      } on DioException catch (e) {
        emit(
          PricingError(
            e.response?.data['message'] ?? 'Failed to update matrix.',
          ),
        );
      }
    });
  }
}
