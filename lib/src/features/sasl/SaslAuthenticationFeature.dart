import 'package:collection/collection.dart' show IterableExtension;
import 'package:xmpp_stone/src/Connection.dart';
import 'package:xmpp_stone/src/elements/nonzas/Nonza.dart';
import 'package:xmpp_stone/src/features/Negotiator.dart';
import 'package:xmpp_stone/src/features/sasl/AbstractSaslHandler.dart';
import 'package:xmpp_stone/src/features/sasl/AnonymousHandler.dart';
import 'package:xmpp_stone/src/features/sasl/PlainSaslHandler.dart';
import 'package:xmpp_stone/src/features/sasl/ScramSaslHandler.dart';

class SaslAuthenticationFeature extends Negotiator {
  final Connection _connection;
  final String _password;

  final Set<SaslMechanism> _offeredMechanisms = {};
  final Set<SaslMechanism> _supportedMechanisms = {};

  SaslAuthenticationFeature(this._connection, this._password) {
    //
    // [2025/02/26 22:08 KSH]속도개선을 위해 PLAIN방식을 사용하도록.
    //
    // _supportedMechanisms.add(SaslMechanism.SCRAM_SHA_1);
    // _supportedMechanisms.add(SaslMechanism.SCRAM_SHA_256);
    _supportedMechanisms.add(SaslMechanism.PLAIN);
    // _supportedMechanisms.add(SaslMechanism.ANONYMOUS);
    expectedName = 'SaslAuthenticationFeature';
  }

  // improve this
  @override
  List<Nonza> match(List<Nonza> requests) {
    var nonza =
        requests.firstWhereOrNull((element) => element.name == 'mechanisms');
    return nonza != null ? [nonza] : [];
  }

  @override
  void negotiate(List<Nonza> nonzas) {
    if (nonzas.isNotEmpty) {
      _populateOfferedMechanism(nonzas[0]);
      _process();
    }
  }

  void _process() {
    var mechanism = _supportedMechanisms.firstWhere(
        (mch) => _offeredMechanisms.contains(mch),
        orElse: _handleAuthNotSupported);
    AbstractSaslHandler? saslHandler;
    switch (mechanism) {
      case SaslMechanism.PLAIN:
        saslHandler = PlainSaslHandler(_connection, _password);
        break;
      case SaslMechanism.SCRAM_SHA_256:
      case SaslMechanism.SCRAM_SHA_1:
        saslHandler = ScramSaslHandler(_connection, _password, mechanism);
        break;
      case SaslMechanism.SCRAM_SHA_1_PLUS:
        break;
      case SaslMechanism.EXTERNAL:
        break;
      case SaslMechanism.ANONYMOUS:
        saslHandler = AnonymousHandler(_connection, mechanism);
        break;
      case SaslMechanism.NOT_SUPPORTED:
        break;
    }
    if (saslHandler != null) {
      state = NegotiatorState.NEGOTIATING;
      saslHandler.start().then((result) {
        if (result.successful) {
          _connection.setState(XmppConnectionState.Authenticated);
        } else {
          _connection.setState(XmppConnectionState.AuthenticationFailure);
          _connection.errorMessage = result.message;
          _connection.close();
        }
        state = NegotiatorState.DONE;
      });
    }
  }

  void _populateOfferedMechanism(Nonza nonza) {
    nonza.children
        .where((element) => element.name == 'mechanism')
        .forEach((mechanism) {
      switch (mechanism.textValue) {
        case 'EXTERNAL':
          _offeredMechanisms.add(SaslMechanism.EXTERNAL);
          break;
        case 'SCRAM-SHA-1-PLUS':
          _offeredMechanisms.add(SaslMechanism.SCRAM_SHA_1_PLUS);
          break;
        case 'SCRAM-SHA-256':
          _offeredMechanisms.add(SaslMechanism.SCRAM_SHA_256);
          break;
        case 'SCRAM-SHA-1':
          _offeredMechanisms.add(SaslMechanism.SCRAM_SHA_1);
          break;
        case 'ANONYMOUS':
          _offeredMechanisms.add(SaslMechanism.ANONYMOUS);
          break;
        case 'PLAIN':
          _offeredMechanisms.add(SaslMechanism.PLAIN);
          break;
      }
    });
  }

  SaslMechanism _handleAuthNotSupported() {
    _connection.setState(XmppConnectionState.AuthenticationNotSupported);
    _connection.close();
    state = NegotiatorState.DONE;
    return SaslMechanism.NOT_SUPPORTED;
  }
}

enum SaslMechanism {
  EXTERNAL,
  SCRAM_SHA_1_PLUS,
  SCRAM_SHA_1,
  SCRAM_SHA_256,
  PLAIN,
  ANONYMOUS,
  NOT_SUPPORTED
}
