import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../../core/api/dio_client.dart';
import '../../data/models/marketing_models.dart';

// --- EVENTS ---
abstract class MarketingEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class FetchMarketingData extends MarketingEvent {}

class CreateCampaign extends MarketingEvent {
  final Map<String, dynamic> payload;
  CreateCampaign(this.payload);
  @override
  List<Object> get props => [payload];
}

class DeleteCampaign extends MarketingEvent {
  final String id;
  DeleteCampaign(this.id);
  @override
  List<Object> get props => [id];
}

class SendEmailBlast extends MarketingEvent {
  final int targetAudience;
  final String subject;
  final String bodyHtml;
  SendEmailBlast({
    required this.targetAudience,
    required this.subject,
    required this.bodyHtml,
  });
  @override
  List<Object> get props => [targetAudience, subject, bodyHtml];
}

class SendPushBlast extends MarketingEvent {
  final int targetAudience;
  final String title;
  final String message;
  SendPushBlast({
    required this.targetAudience,
    required this.title,
    required this.message,
  });
  @override
  List<Object> get props => [targetAudience, title, message];
}

// --- STATES ---
abstract class MarketingState extends Equatable {
  @override
  List<Object> get props => [];
}

class MarketingLoading extends MarketingState {}

class MarketingLoaded extends MarketingState {
  final List<MarketingCampaignModel> campaigns;
  final List<EmailLogModel> emailLogs;
  final List<NotificationLogModel> notificationLogs;

  MarketingLoaded(this.campaigns, this.emailLogs, this.notificationLogs);
  @override
  List<Object> get props => [campaigns, emailLogs, notificationLogs];
}

class MarketingActionSuccess extends MarketingState {
  final String message;
  MarketingActionSuccess(this.message);
  @override
  List<Object> get props => [message];
}

class MarketingError extends MarketingState {
  final String message;
  MarketingError(this.message);
  @override
  List<Object> get props => [message];
}

// --- BLOC ---
class MarketingBloc extends Bloc<MarketingEvent, MarketingState> {
  final DioClient dioClient;

  MarketingBloc({required this.dioClient}) : super(MarketingLoading()) {
    on<FetchMarketingData>((event, emit) async {
      emit(MarketingLoading());
      try {
        final responses = await Future.wait([
          dioClient.dio
              .get('/api/marketing/campaigns')
              .catchError(
                (_) => Response(requestOptions: RequestOptions(), data: []),
              ),
          dioClient.dio
              .get('/api/marketing/emails/history')
              .catchError(
                (_) => Response(requestOptions: RequestOptions(), data: []),
              ),
          dioClient.dio
              .get('/api/marketing/notifications/history')
              .catchError(
                (_) => Response(requestOptions: RequestOptions(), data: []),
              ),
        ]);

        final campaigns = (responses[0].data as List)
            .map((j) => MarketingCampaignModel.fromJson(j))
            .toList();
        final emailLogs = (responses[1].data as List)
            .map((j) => EmailLogModel.fromJson(j))
            .toList();
        final notificationLogs = (responses[2].data as List)
            .map((j) => NotificationLogModel.fromJson(j))
            .toList();

        emit(MarketingLoaded(campaigns, emailLogs, notificationLogs));
      } catch (e) {
        emit(MarketingError('Failed to retrieve marketing hub records.'));
      }
    });

    on<CreateCampaign>((event, emit) async {
      try {
        final res = await dioClient.dio.post(
          '/api/marketing/campaigns',
          data: event.payload,
        );
        emit(
          MarketingActionSuccess(
            res.data?['message'] ?? 'Campaign created successfully.',
          ),
        );
        add(FetchMarketingData());
      } on DioException catch (e) {
        emit(
          MarketingError(
            e.response?.data?['message'] ?? 'Failed to create campaign.',
          ),
        );
      } catch (_) {
        emit(MarketingError('Failed to create campaign.'));
      }
    });

    on<DeleteCampaign>((event, emit) async {
      try {
        await dioClient.dio.delete('/api/marketing/campaigns/${event.id}');
        emit(MarketingActionSuccess('Campaign removed from tracker.'));
        add(FetchMarketingData());
      } catch (e) {
        emit(MarketingError('Failed to delete campaign.'));
      }
    });

    on<SendEmailBlast>((event, emit) async {
      try {
        final res = await dioClient.dio.post(
          '/api/marketing/emails/send',
          data: {
            'targetAudience': event.targetAudience,
            'subject': event.subject,
            'bodyHtml': event.bodyHtml,
          },
        );
        emit(
          MarketingActionSuccess(
            res.data?['message'] ?? 'Email blast executed successfully.',
          ),
        );
        add(FetchMarketingData());
      } catch (e) {
        emit(
          MarketingError(
            'Email dispatch failed. Verify MailerSend API settings.',
          ),
        );
      }
    });

    on<SendPushBlast>((event, emit) async {
      try {
        final res = await dioClient.dio.post(
          '/api/marketing/notifications/send',
          data: {
            'targetAudience': event.targetAudience,
            'title': event.title,
            'message': event.message,
          },
        );
        emit(
          MarketingActionSuccess(
            res.data?['message'] ?? 'Push notification broadcasted.',
          ),
        );
        add(FetchMarketingData());
      } catch (e) {
        emit(MarketingError('Push notification broadcast failed.'));
      }
    });
  }
}
