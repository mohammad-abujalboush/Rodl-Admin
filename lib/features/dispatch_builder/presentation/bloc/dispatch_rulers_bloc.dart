import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../../core/api/dio_client.dart';
import '../../data/models/dispatch_graph_model.dart';

class DispatchVersionHistory {
  final int id;
  final String version;
  final String description;
  final String jsonPayload;
  final bool isActive;

  DispatchVersionHistory({
    required this.id,
    required this.version,
    required this.description,
    required this.jsonPayload,
    required this.isActive,
  });

  factory DispatchVersionHistory.fromJson(Map<String, dynamic> json) =>
      DispatchVersionHistory(
        id: json['id'],
        version: json['version'] ?? '1.0',
        description: json['description'] ?? 'System Update',
        jsonPayload: json['jsonPayload'] ?? '{}',
        isActive: json['isActive'] ?? false,
      );
}

abstract class DispatchRulesEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchRulesEvent extends DispatchRulesEvent {}

class FetchRulesHistoryEvent extends DispatchRulesEvent {}

class LoadSpecificVersionEvent extends DispatchRulesEvent {
  final String jsonPayload;
  LoadSpecificVersionEvent(this.jsonPayload);
  @override
  List<Object> get props => [jsonPayload];
}

class SaveRulesEvent extends DispatchRulesEvent {
  final String jsonPayload;
  final String description;
  SaveRulesEvent(this.jsonPayload, this.description);
  @override
  List<Object> get props => [jsonPayload, description];
}

abstract class DispatchRulesState extends Equatable {
  @override
  List<Object> get props => [];
}

class RulesLoading extends DispatchRulesState {}

class RulesLoaded extends DispatchRulesState {
  final List<DispatchNode> nodes;
  final List<DispatchEdge> edges;
  final List<PricingRuleOption> activeServices;
  final String? activeVersion;

  RulesLoaded(
    this.nodes,
    this.edges,
    this.activeServices, {
    this.activeVersion,
  });
  @override
  List<Object> get props => [nodes, edges, activeServices, activeVersion ?? ''];
}

class RulesHistoryLoaded extends DispatchRulesState {
  final List<DispatchVersionHistory> history;
  RulesHistoryLoaded(this.history);
  @override
  List<Object> get props => [history];
}

class RulesError extends DispatchRulesState {
  final String message;
  RulesError(this.message);
  @override
  List<Object> get props => [message];
}

class RulesSaveSuccess extends DispatchRulesState {}

class DispatchRulesBloc extends Bloc<DispatchRulesEvent, DispatchRulesState> {
  final DioClient dioClient;
  List<PricingRuleOption> _cachedServices = [];

  DispatchRulesBloc({required this.dioClient}) : super(RulesLoading()) {
    on<FetchRulesEvent>((event, emit) async {
      emit(RulesLoading());
      try {
        // Fetch Graph AND Pricing Data Simultaneously
        final responses = await Future.wait([
          dioClient.dio.get('/api/dispatchrules'),
          dioClient.dio.get('/api/admin/pricing-rules'),
        ]);

        // Process Pricing Data
        final pricingData = responses[1].data as List;
        _cachedServices = pricingData
            .map((e) => PricingRuleOption.fromJson(e))
            .where((e) => e.isActive)
            .toList();

        // Process Graph Data
        final responseData = responses[0].data;
        final String? rawJson = responseData['jsonPayload'];
        final String version = responseData['version'] ?? '1.0';

        if (rawJson == null || rawJson.isEmpty || rawJson == "{}") {
          emit(
            RulesLoaded(
              const [],
              const [],
              _cachedServices,
              activeVersion: version,
            ),
          );
          return;
        }

        final Map<String, dynamic> payload = jsonDecode(rawJson);
        final nodes = (payload['nodes'] as List)
            .map((n) => DispatchNode.fromJson(n))
            .toList();
        final edges = (payload['edges'] as List)
            .map((e) => DispatchEdge.fromJson(e))
            .toList();

        emit(
          RulesLoaded(nodes, edges, _cachedServices, activeVersion: version),
        );
      } catch (e) {
        emit(
          RulesError('Failed to load dispatch rules or pricing parameters.'),
        );
      }
    });

    on<FetchRulesHistoryEvent>((event, emit) async {
      try {
        final response = await dioClient.dio.get('/api/dispatchrules/history');
        if (response.statusCode == 200) {
          final list = (response.data as List)
              .map((x) => DispatchVersionHistory.fromJson(x))
              .toList();
          emit(RulesHistoryLoaded(list));
        }
      } catch (e) {
        emit(RulesError('Failed to load version history.'));
      }
    });

    on<LoadSpecificVersionEvent>((event, emit) async {
      try {
        final Map<String, dynamic> payload = jsonDecode(event.jsonPayload);
        final nodes = (payload['nodes'] as List)
            .map((n) => DispatchNode.fromJson(n))
            .toList();
        final edges = (payload['edges'] as List)
            .map((e) => DispatchEdge.fromJson(e))
            .toList();
        emit(
          RulesLoaded(
            nodes,
            edges,
            _cachedServices,
            activeVersion: "Preview Mode",
          ),
        );
      } catch (e) {
        emit(RulesError('Failed to parse the selected version.'));
      }
    });

    on<SaveRulesEvent>((event, emit) async {
      try {
        final response = await dioClient.dio.put(
          '/api/dispatchrules',
          data: {
            'version': '1.0',
            'description': event.description,
            'jsonPayload': event.jsonPayload,
          },
        );

        if (response.statusCode == 200) {
          emit(RulesSaveSuccess());
          add(FetchRulesEvent());
        } else {
          emit(RulesError('Failed to save rules to the database.'));
        }
      } catch (e) {
        emit(RulesError('Network error while saving dispatch rules.'));
      }
    });
  }
}
