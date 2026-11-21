// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $UserProfilesTable extends UserProfiles
    with TableInfo<$UserProfilesTable, UserProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ProfileKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ProfileKind>($UserProfilesTable.$converterkind);
  static const VerificationMeta _mountMeta = const VerificationMeta('mount');
  @override
  late final GeneratedColumn<String> mount = GeneratedColumn<String>(
    'mount',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, kind, mount, json, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('mount')) {
      context.handle(
        _mountMeta,
        mount.isAcceptableOrUnknown(data['mount']!, _mountMeta),
      );
    } else if (isInserting) {
      context.missing(_mountMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {kind, id};
  @override
  UserProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: $UserProfilesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      mount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mount'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UserProfilesTable createAlias(String alias) {
    return $UserProfilesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ProfileKind, String, String> $converterkind =
      const EnumNameConverter<ProfileKind>(ProfileKind.values);
}

class UserProfile extends DataClass implements Insertable<UserProfile> {
  final String id;
  final ProfileKind kind;
  final String mount;

  /// jsonEncode(gearToJson(profile))
  final String json;
  final DateTime updatedAt;
  const UserProfile({
    required this.id,
    required this.kind,
    required this.mount,
    required this.json,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['kind'] = Variable<String>(
        $UserProfilesTable.$converterkind.toSql(kind),
      );
    }
    map['mount'] = Variable<String>(mount);
    map['json'] = Variable<String>(json);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserProfilesCompanion toCompanion(bool nullToAbsent) {
    return UserProfilesCompanion(
      id: Value(id),
      kind: Value(kind),
      mount: Value(mount),
      json: Value(json),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfile(
      id: serializer.fromJson<String>(json['id']),
      kind: $UserProfilesTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      mount: serializer.fromJson<String>(json['mount']),
      json: serializer.fromJson<String>(json['json']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(
        $UserProfilesTable.$converterkind.toJson(kind),
      ),
      'mount': serializer.toJson<String>(mount),
      'json': serializer.toJson<String>(json),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserProfile copyWith({
    String? id,
    ProfileKind? kind,
    String? mount,
    String? json,
    DateTime? updatedAt,
  }) => UserProfile(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    mount: mount ?? this.mount,
    json: json ?? this.json,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserProfile copyWithCompanion(UserProfilesCompanion data) {
    return UserProfile(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      mount: data.mount.present ? data.mount.value : this.mount,
      json: data.json.present ? data.json.value : this.json,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfile(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('mount: $mount, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, mount, json, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfile &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.mount == this.mount &&
          other.json == this.json &&
          other.updatedAt == this.updatedAt);
}

class UserProfilesCompanion extends UpdateCompanion<UserProfile> {
  final Value<String> id;
  final Value<ProfileKind> kind;
  final Value<String> mount;
  final Value<String> json;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const UserProfilesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.mount = const Value.absent(),
    this.json = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserProfilesCompanion.insert({
    required String id,
    required ProfileKind kind,
    required String mount,
    required String json,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       mount = Value(mount),
       json = Value(json),
       updatedAt = Value(updatedAt);
  static Insertable<UserProfile> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? mount,
    Expression<String>? json,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (mount != null) 'mount': mount,
      if (json != null) 'json': json,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserProfilesCompanion copyWith({
    Value<String>? id,
    Value<ProfileKind>? kind,
    Value<String>? mount,
    Value<String>? json,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return UserProfilesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      mount: mount ?? this.mount,
      json: json ?? this.json,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $UserProfilesTable.$converterkind.toSql(kind.value),
      );
    }
    if (mount.present) {
      map['mount'] = Variable<String>(mount.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfilesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('mount: $mount, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoritesTable extends Favorites
    with TableInfo<$FavoritesTable, Favorite> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritesTable(this.attachedDatabase, [this._alias]);
  @override
  late final GeneratedColumnWithTypeConverter<ProfileKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ProfileKind>($FavoritesTable.$converterkind);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [kind, profileId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<Favorite> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {kind, profileId};
  @override
  Favorite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Favorite(
      kind: $FavoritesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
    );
  }

  @override
  $FavoritesTable createAlias(String alias) {
    return $FavoritesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ProfileKind, String, String> $converterkind =
      const EnumNameConverter<ProfileKind>(ProfileKind.values);
}

class Favorite extends DataClass implements Insertable<Favorite> {
  final ProfileKind kind;
  final String profileId;
  const Favorite({required this.kind, required this.profileId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    {
      map['kind'] = Variable<String>(
        $FavoritesTable.$converterkind.toSql(kind),
      );
    }
    map['profile_id'] = Variable<String>(profileId);
    return map;
  }

  FavoritesCompanion toCompanion(bool nullToAbsent) {
    return FavoritesCompanion(kind: Value(kind), profileId: Value(profileId));
  }

  factory Favorite.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Favorite(
      kind: $FavoritesTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      profileId: serializer.fromJson<String>(json['profileId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kind': serializer.toJson<String>(
        $FavoritesTable.$converterkind.toJson(kind),
      ),
      'profileId': serializer.toJson<String>(profileId),
    };
  }

  Favorite copyWith({ProfileKind? kind, String? profileId}) =>
      Favorite(kind: kind ?? this.kind, profileId: profileId ?? this.profileId);
  Favorite copyWithCompanion(FavoritesCompanion data) {
    return Favorite(
      kind: data.kind.present ? data.kind.value : this.kind,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Favorite(')
          ..write('kind: $kind, ')
          ..write('profileId: $profileId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(kind, profileId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Favorite &&
          other.kind == this.kind &&
          other.profileId == this.profileId);
}

class FavoritesCompanion extends UpdateCompanion<Favorite> {
  final Value<ProfileKind> kind;
  final Value<String> profileId;
  final Value<int> rowid;
  const FavoritesCompanion({
    this.kind = const Value.absent(),
    this.profileId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoritesCompanion.insert({
    required ProfileKind kind,
    required String profileId,
    this.rowid = const Value.absent(),
  }) : kind = Value(kind),
       profileId = Value(profileId);
  static Insertable<Favorite> custom({
    Expression<String>? kind,
    Expression<String>? profileId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kind != null) 'kind': kind,
      if (profileId != null) 'profile_id': profileId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoritesCompanion copyWith({
    Value<ProfileKind>? kind,
    Value<String>? profileId,
    Value<int>? rowid,
  }) {
    return FavoritesCompanion(
      kind: kind ?? this.kind,
      profileId: profileId ?? this.profileId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kind.present) {
      map['kind'] = Variable<String>(
        $FavoritesTable.$converterkind.toSql(kind.value),
      );
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesCompanion(')
          ..write('kind: $kind, ')
          ..write('profileId: $profileId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GearSelectionsTable extends GearSelections
    with TableInfo<$GearSelectionsTable, GearSelection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GearSelectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _bodyIdMeta = const VerificationMeta('bodyId');
  @override
  late final GeneratedColumn<String> bodyId = GeneratedColumn<String>(
    'body_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lensIdMeta = const VerificationMeta('lensId');
  @override
  late final GeneratedColumn<String> lensId = GeneratedColumn<String>(
    'lens_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _focalMeta = const VerificationMeta('focal');
  @override
  late final GeneratedColumn<double> focal = GeneratedColumn<double>(
    'focal',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, bodyId, lensId, focal];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gear_selections';
  @override
  VerificationContext validateIntegrity(
    Insertable<GearSelection> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('body_id')) {
      context.handle(
        _bodyIdMeta,
        bodyId.isAcceptableOrUnknown(data['body_id']!, _bodyIdMeta),
      );
    }
    if (data.containsKey('lens_id')) {
      context.handle(
        _lensIdMeta,
        lensId.isAcceptableOrUnknown(data['lens_id']!, _lensIdMeta),
      );
    }
    if (data.containsKey('focal')) {
      context.handle(
        _focalMeta,
        focal.isAcceptableOrUnknown(data['focal']!, _focalMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GearSelection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GearSelection(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bodyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_id'],
      ),
      lensId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lens_id'],
      ),
      focal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}focal'],
      ),
    );
  }

  @override
  $GearSelectionsTable createAlias(String alias) {
    return $GearSelectionsTable(attachedDatabase, alias);
  }
}

class GearSelection extends DataClass implements Insertable<GearSelection> {
  final int id;
  final String? bodyId;
  final String? lensId;
  final double? focal;
  const GearSelection({required this.id, this.bodyId, this.lensId, this.focal});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || bodyId != null) {
      map['body_id'] = Variable<String>(bodyId);
    }
    if (!nullToAbsent || lensId != null) {
      map['lens_id'] = Variable<String>(lensId);
    }
    if (!nullToAbsent || focal != null) {
      map['focal'] = Variable<double>(focal);
    }
    return map;
  }

  GearSelectionsCompanion toCompanion(bool nullToAbsent) {
    return GearSelectionsCompanion(
      id: Value(id),
      bodyId: bodyId == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyId),
      lensId: lensId == null && nullToAbsent
          ? const Value.absent()
          : Value(lensId),
      focal: focal == null && nullToAbsent
          ? const Value.absent()
          : Value(focal),
    );
  }

  factory GearSelection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GearSelection(
      id: serializer.fromJson<int>(json['id']),
      bodyId: serializer.fromJson<String?>(json['bodyId']),
      lensId: serializer.fromJson<String?>(json['lensId']),
      focal: serializer.fromJson<double?>(json['focal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bodyId': serializer.toJson<String?>(bodyId),
      'lensId': serializer.toJson<String?>(lensId),
      'focal': serializer.toJson<double?>(focal),
    };
  }

  GearSelection copyWith({
    int? id,
    Value<String?> bodyId = const Value.absent(),
    Value<String?> lensId = const Value.absent(),
    Value<double?> focal = const Value.absent(),
  }) => GearSelection(
    id: id ?? this.id,
    bodyId: bodyId.present ? bodyId.value : this.bodyId,
    lensId: lensId.present ? lensId.value : this.lensId,
    focal: focal.present ? focal.value : this.focal,
  );
  GearSelection copyWithCompanion(GearSelectionsCompanion data) {
    return GearSelection(
      id: data.id.present ? data.id.value : this.id,
      bodyId: data.bodyId.present ? data.bodyId.value : this.bodyId,
      lensId: data.lensId.present ? data.lensId.value : this.lensId,
      focal: data.focal.present ? data.focal.value : this.focal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GearSelection(')
          ..write('id: $id, ')
          ..write('bodyId: $bodyId, ')
          ..write('lensId: $lensId, ')
          ..write('focal: $focal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, bodyId, lensId, focal);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GearSelection &&
          other.id == this.id &&
          other.bodyId == this.bodyId &&
          other.lensId == this.lensId &&
          other.focal == this.focal);
}

class GearSelectionsCompanion extends UpdateCompanion<GearSelection> {
  final Value<int> id;
  final Value<String?> bodyId;
  final Value<String?> lensId;
  final Value<double?> focal;
  const GearSelectionsCompanion({
    this.id = const Value.absent(),
    this.bodyId = const Value.absent(),
    this.lensId = const Value.absent(),
    this.focal = const Value.absent(),
  });
  GearSelectionsCompanion.insert({
    this.id = const Value.absent(),
    this.bodyId = const Value.absent(),
    this.lensId = const Value.absent(),
    this.focal = const Value.absent(),
  });
  static Insertable<GearSelection> custom({
    Expression<int>? id,
    Expression<String>? bodyId,
    Expression<String>? lensId,
    Expression<double>? focal,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bodyId != null) 'body_id': bodyId,
      if (lensId != null) 'lens_id': lensId,
      if (focal != null) 'focal': focal,
    });
  }

  GearSelectionsCompanion copyWith({
    Value<int>? id,
    Value<String?>? bodyId,
    Value<String?>? lensId,
    Value<double?>? focal,
  }) {
    return GearSelectionsCompanion(
      id: id ?? this.id,
      bodyId: bodyId ?? this.bodyId,
      lensId: lensId ?? this.lensId,
      focal: focal ?? this.focal,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bodyId.present) {
      map['body_id'] = Variable<String>(bodyId.value);
    }
    if (lensId.present) {
      map['lens_id'] = Variable<String>(lensId.value);
    }
    if (focal.present) {
      map['focal'] = Variable<double>(focal.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GearSelectionsCompanion(')
          ..write('id: $id, ')
          ..write('bodyId: $bodyId, ')
          ..write('lensId: $lensId, ')
          ..write('focal: $focal')
          ..write(')'))
        .toString();
  }
}

class $RollsTable extends Rolls with TableInfo<$RollsTable, RollRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RollsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<int> number = GeneratedColumn<int>(
    'number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filmStockMeta = const VerificationMeta(
    'filmStock',
  );
  @override
  late final GeneratedColumn<String> filmStock = GeneratedColumn<String>(
    'film_stock',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filmTypeMeta = const VerificationMeta(
    'filmType',
  );
  @override
  late final GeneratedColumn<String> filmType = GeneratedColumn<String>(
    'film_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _boxIsoMeta = const VerificationMeta('boxIso');
  @override
  late final GeneratedColumn<int> boxIso = GeneratedColumn<int>(
    'box_iso',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pushThirdsMeta = const VerificationMeta(
    'pushThirds',
  );
  @override
  late final GeneratedColumn<int> pushThirds = GeneratedColumn<int>(
    'push_thirds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyIdMeta = const VerificationMeta('bodyId');
  @override
  late final GeneratedColumn<String> bodyId = GeneratedColumn<String>(
    'body_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyMakeMeta = const VerificationMeta(
    'bodyMake',
  );
  @override
  late final GeneratedColumn<String> bodyMake = GeneratedColumn<String>(
    'body_make',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyModelMeta = const VerificationMeta(
    'bodyModel',
  );
  @override
  late final GeneratedColumn<String> bodyModel = GeneratedColumn<String>(
    'body_model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startFrameMeta = const VerificationMeta(
    'startFrame',
  );
  @override
  late final GeneratedColumn<String> startFrame = GeneratedColumn<String>(
    'start_frame',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _latitudeUnderHalvesMeta =
      const VerificationMeta('latitudeUnderHalves');
  @override
  late final GeneratedColumn<int> latitudeUnderHalves = GeneratedColumn<int>(
    'latitude_under_halves',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latitudeOverHalvesMeta =
      const VerificationMeta('latitudeOverHalves');
  @override
  late final GeneratedColumn<int> latitudeOverHalves = GeneratedColumn<int>(
    'latitude_over_halves',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    number,
    filmStock,
    filmType,
    boxIso,
    pushThirds,
    bodyId,
    bodyMake,
    bodyModel,
    format,
    size,
    startFrame,
    notes,
    latitudeUnderHalves,
    latitudeOverHalves,
    status,
    startedAt,
    finishedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rolls';
  @override
  VerificationContext validateIntegrity(
    Insertable<RollRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('film_stock')) {
      context.handle(
        _filmStockMeta,
        filmStock.isAcceptableOrUnknown(data['film_stock']!, _filmStockMeta),
      );
    } else if (isInserting) {
      context.missing(_filmStockMeta);
    }
    if (data.containsKey('film_type')) {
      context.handle(
        _filmTypeMeta,
        filmType.isAcceptableOrUnknown(data['film_type']!, _filmTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_filmTypeMeta);
    }
    if (data.containsKey('box_iso')) {
      context.handle(
        _boxIsoMeta,
        boxIso.isAcceptableOrUnknown(data['box_iso']!, _boxIsoMeta),
      );
    } else if (isInserting) {
      context.missing(_boxIsoMeta);
    }
    if (data.containsKey('push_thirds')) {
      context.handle(
        _pushThirdsMeta,
        pushThirds.isAcceptableOrUnknown(data['push_thirds']!, _pushThirdsMeta),
      );
    } else if (isInserting) {
      context.missing(_pushThirdsMeta);
    }
    if (data.containsKey('body_id')) {
      context.handle(
        _bodyIdMeta,
        bodyId.isAcceptableOrUnknown(data['body_id']!, _bodyIdMeta),
      );
    }
    if (data.containsKey('body_make')) {
      context.handle(
        _bodyMakeMeta,
        bodyMake.isAcceptableOrUnknown(data['body_make']!, _bodyMakeMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMakeMeta);
    }
    if (data.containsKey('body_model')) {
      context.handle(
        _bodyModelMeta,
        bodyModel.isAcceptableOrUnknown(data['body_model']!, _bodyModelMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyModelMeta);
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('start_frame')) {
      context.handle(
        _startFrameMeta,
        startFrame.isAcceptableOrUnknown(data['start_frame']!, _startFrameMeta),
      );
    } else if (isInserting) {
      context.missing(_startFrameMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('latitude_under_halves')) {
      context.handle(
        _latitudeUnderHalvesMeta,
        latitudeUnderHalves.isAcceptableOrUnknown(
          data['latitude_under_halves']!,
          _latitudeUnderHalvesMeta,
        ),
      );
    }
    if (data.containsKey('latitude_over_halves')) {
      context.handle(
        _latitudeOverHalvesMeta,
        latitudeOverHalves.isAcceptableOrUnknown(
          data['latitude_over_halves']!,
          _latitudeOverHalvesMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RollRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RollRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}number'],
      )!,
      filmStock: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}film_stock'],
      )!,
      filmType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}film_type'],
      )!,
      boxIso: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}box_iso'],
      )!,
      pushThirds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}push_thirds'],
      )!,
      bodyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_id'],
      ),
      bodyMake: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_make'],
      )!,
      bodyModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_model'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      startFrame: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_frame'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      latitudeUnderHalves: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}latitude_under_halves'],
      ),
      latitudeOverHalves: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}latitude_over_halves'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RollsTable createAlias(String alias) {
    return $RollsTable(attachedDatabase, alias);
  }
}

class RollRow extends DataClass implements Insertable<RollRow> {
  final String id;
  final int number;
  final String filmStock;

  /// FilmType.id
  final String filmType;
  final int boxIso;
  final int pushThirds;
  final String? bodyId;
  final String bodyMake;
  final String bodyModel;

  /// FilmFormat.id
  final String format;
  final int size;

  /// StartFrame.label
  final String startFrame;
  final String notes;

  /// Film latitude override in half stops; null follows the film type.
  final int? latitudeUnderHalves;
  final int? latitudeOverHalves;

  /// RollStatus.name
  final String status;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final DateTime updatedAt;
  const RollRow({
    required this.id,
    required this.number,
    required this.filmStock,
    required this.filmType,
    required this.boxIso,
    required this.pushThirds,
    this.bodyId,
    required this.bodyMake,
    required this.bodyModel,
    required this.format,
    required this.size,
    required this.startFrame,
    required this.notes,
    this.latitudeUnderHalves,
    this.latitudeOverHalves,
    required this.status,
    required this.startedAt,
    this.finishedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['number'] = Variable<int>(number);
    map['film_stock'] = Variable<String>(filmStock);
    map['film_type'] = Variable<String>(filmType);
    map['box_iso'] = Variable<int>(boxIso);
    map['push_thirds'] = Variable<int>(pushThirds);
    if (!nullToAbsent || bodyId != null) {
      map['body_id'] = Variable<String>(bodyId);
    }
    map['body_make'] = Variable<String>(bodyMake);
    map['body_model'] = Variable<String>(bodyModel);
    map['format'] = Variable<String>(format);
    map['size'] = Variable<int>(size);
    map['start_frame'] = Variable<String>(startFrame);
    map['notes'] = Variable<String>(notes);
    if (!nullToAbsent || latitudeUnderHalves != null) {
      map['latitude_under_halves'] = Variable<int>(latitudeUnderHalves);
    }
    if (!nullToAbsent || latitudeOverHalves != null) {
      map['latitude_over_halves'] = Variable<int>(latitudeOverHalves);
    }
    map['status'] = Variable<String>(status);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RollsCompanion toCompanion(bool nullToAbsent) {
    return RollsCompanion(
      id: Value(id),
      number: Value(number),
      filmStock: Value(filmStock),
      filmType: Value(filmType),
      boxIso: Value(boxIso),
      pushThirds: Value(pushThirds),
      bodyId: bodyId == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyId),
      bodyMake: Value(bodyMake),
      bodyModel: Value(bodyModel),
      format: Value(format),
      size: Value(size),
      startFrame: Value(startFrame),
      notes: Value(notes),
      latitudeUnderHalves: latitudeUnderHalves == null && nullToAbsent
          ? const Value.absent()
          : Value(latitudeUnderHalves),
      latitudeOverHalves: latitudeOverHalves == null && nullToAbsent
          ? const Value.absent()
          : Value(latitudeOverHalves),
      status: Value(status),
      startedAt: Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory RollRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RollRow(
      id: serializer.fromJson<String>(json['id']),
      number: serializer.fromJson<int>(json['number']),
      filmStock: serializer.fromJson<String>(json['filmStock']),
      filmType: serializer.fromJson<String>(json['filmType']),
      boxIso: serializer.fromJson<int>(json['boxIso']),
      pushThirds: serializer.fromJson<int>(json['pushThirds']),
      bodyId: serializer.fromJson<String?>(json['bodyId']),
      bodyMake: serializer.fromJson<String>(json['bodyMake']),
      bodyModel: serializer.fromJson<String>(json['bodyModel']),
      format: serializer.fromJson<String>(json['format']),
      size: serializer.fromJson<int>(json['size']),
      startFrame: serializer.fromJson<String>(json['startFrame']),
      notes: serializer.fromJson<String>(json['notes']),
      latitudeUnderHalves: serializer.fromJson<int?>(
        json['latitudeUnderHalves'],
      ),
      latitudeOverHalves: serializer.fromJson<int?>(json['latitudeOverHalves']),
      status: serializer.fromJson<String>(json['status']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'number': serializer.toJson<int>(number),
      'filmStock': serializer.toJson<String>(filmStock),
      'filmType': serializer.toJson<String>(filmType),
      'boxIso': serializer.toJson<int>(boxIso),
      'pushThirds': serializer.toJson<int>(pushThirds),
      'bodyId': serializer.toJson<String?>(bodyId),
      'bodyMake': serializer.toJson<String>(bodyMake),
      'bodyModel': serializer.toJson<String>(bodyModel),
      'format': serializer.toJson<String>(format),
      'size': serializer.toJson<int>(size),
      'startFrame': serializer.toJson<String>(startFrame),
      'notes': serializer.toJson<String>(notes),
      'latitudeUnderHalves': serializer.toJson<int?>(latitudeUnderHalves),
      'latitudeOverHalves': serializer.toJson<int?>(latitudeOverHalves),
      'status': serializer.toJson<String>(status),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RollRow copyWith({
    String? id,
    int? number,
    String? filmStock,
    String? filmType,
    int? boxIso,
    int? pushThirds,
    Value<String?> bodyId = const Value.absent(),
    String? bodyMake,
    String? bodyModel,
    String? format,
    int? size,
    String? startFrame,
    String? notes,
    Value<int?> latitudeUnderHalves = const Value.absent(),
    Value<int?> latitudeOverHalves = const Value.absent(),
    String? status,
    DateTime? startedAt,
    Value<DateTime?> finishedAt = const Value.absent(),
    DateTime? updatedAt,
  }) => RollRow(
    id: id ?? this.id,
    number: number ?? this.number,
    filmStock: filmStock ?? this.filmStock,
    filmType: filmType ?? this.filmType,
    boxIso: boxIso ?? this.boxIso,
    pushThirds: pushThirds ?? this.pushThirds,
    bodyId: bodyId.present ? bodyId.value : this.bodyId,
    bodyMake: bodyMake ?? this.bodyMake,
    bodyModel: bodyModel ?? this.bodyModel,
    format: format ?? this.format,
    size: size ?? this.size,
    startFrame: startFrame ?? this.startFrame,
    notes: notes ?? this.notes,
    latitudeUnderHalves: latitudeUnderHalves.present
        ? latitudeUnderHalves.value
        : this.latitudeUnderHalves,
    latitudeOverHalves: latitudeOverHalves.present
        ? latitudeOverHalves.value
        : this.latitudeOverHalves,
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  RollRow copyWithCompanion(RollsCompanion data) {
    return RollRow(
      id: data.id.present ? data.id.value : this.id,
      number: data.number.present ? data.number.value : this.number,
      filmStock: data.filmStock.present ? data.filmStock.value : this.filmStock,
      filmType: data.filmType.present ? data.filmType.value : this.filmType,
      boxIso: data.boxIso.present ? data.boxIso.value : this.boxIso,
      pushThirds: data.pushThirds.present
          ? data.pushThirds.value
          : this.pushThirds,
      bodyId: data.bodyId.present ? data.bodyId.value : this.bodyId,
      bodyMake: data.bodyMake.present ? data.bodyMake.value : this.bodyMake,
      bodyModel: data.bodyModel.present ? data.bodyModel.value : this.bodyModel,
      format: data.format.present ? data.format.value : this.format,
      size: data.size.present ? data.size.value : this.size,
      startFrame: data.startFrame.present
          ? data.startFrame.value
          : this.startFrame,
      notes: data.notes.present ? data.notes.value : this.notes,
      latitudeUnderHalves: data.latitudeUnderHalves.present
          ? data.latitudeUnderHalves.value
          : this.latitudeUnderHalves,
      latitudeOverHalves: data.latitudeOverHalves.present
          ? data.latitudeOverHalves.value
          : this.latitudeOverHalves,
      status: data.status.present ? data.status.value : this.status,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RollRow(')
          ..write('id: $id, ')
          ..write('number: $number, ')
          ..write('filmStock: $filmStock, ')
          ..write('filmType: $filmType, ')
          ..write('boxIso: $boxIso, ')
          ..write('pushThirds: $pushThirds, ')
          ..write('bodyId: $bodyId, ')
          ..write('bodyMake: $bodyMake, ')
          ..write('bodyModel: $bodyModel, ')
          ..write('format: $format, ')
          ..write('size: $size, ')
          ..write('startFrame: $startFrame, ')
          ..write('notes: $notes, ')
          ..write('latitudeUnderHalves: $latitudeUnderHalves, ')
          ..write('latitudeOverHalves: $latitudeOverHalves, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    number,
    filmStock,
    filmType,
    boxIso,
    pushThirds,
    bodyId,
    bodyMake,
    bodyModel,
    format,
    size,
    startFrame,
    notes,
    latitudeUnderHalves,
    latitudeOverHalves,
    status,
    startedAt,
    finishedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RollRow &&
          other.id == this.id &&
          other.number == this.number &&
          other.filmStock == this.filmStock &&
          other.filmType == this.filmType &&
          other.boxIso == this.boxIso &&
          other.pushThirds == this.pushThirds &&
          other.bodyId == this.bodyId &&
          other.bodyMake == this.bodyMake &&
          other.bodyModel == this.bodyModel &&
          other.format == this.format &&
          other.size == this.size &&
          other.startFrame == this.startFrame &&
          other.notes == this.notes &&
          other.latitudeUnderHalves == this.latitudeUnderHalves &&
          other.latitudeOverHalves == this.latitudeOverHalves &&
          other.status == this.status &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt &&
          other.updatedAt == this.updatedAt);
}

class RollsCompanion extends UpdateCompanion<RollRow> {
  final Value<String> id;
  final Value<int> number;
  final Value<String> filmStock;
  final Value<String> filmType;
  final Value<int> boxIso;
  final Value<int> pushThirds;
  final Value<String?> bodyId;
  final Value<String> bodyMake;
  final Value<String> bodyModel;
  final Value<String> format;
  final Value<int> size;
  final Value<String> startFrame;
  final Value<String> notes;
  final Value<int?> latitudeUnderHalves;
  final Value<int?> latitudeOverHalves;
  final Value<String> status;
  final Value<DateTime> startedAt;
  final Value<DateTime?> finishedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const RollsCompanion({
    this.id = const Value.absent(),
    this.number = const Value.absent(),
    this.filmStock = const Value.absent(),
    this.filmType = const Value.absent(),
    this.boxIso = const Value.absent(),
    this.pushThirds = const Value.absent(),
    this.bodyId = const Value.absent(),
    this.bodyMake = const Value.absent(),
    this.bodyModel = const Value.absent(),
    this.format = const Value.absent(),
    this.size = const Value.absent(),
    this.startFrame = const Value.absent(),
    this.notes = const Value.absent(),
    this.latitudeUnderHalves = const Value.absent(),
    this.latitudeOverHalves = const Value.absent(),
    this.status = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RollsCompanion.insert({
    required String id,
    required int number,
    required String filmStock,
    required String filmType,
    required int boxIso,
    required int pushThirds,
    this.bodyId = const Value.absent(),
    required String bodyMake,
    required String bodyModel,
    required String format,
    required int size,
    required String startFrame,
    this.notes = const Value.absent(),
    this.latitudeUnderHalves = const Value.absent(),
    this.latitudeOverHalves = const Value.absent(),
    required String status,
    required DateTime startedAt,
    this.finishedAt = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       number = Value(number),
       filmStock = Value(filmStock),
       filmType = Value(filmType),
       boxIso = Value(boxIso),
       pushThirds = Value(pushThirds),
       bodyMake = Value(bodyMake),
       bodyModel = Value(bodyModel),
       format = Value(format),
       size = Value(size),
       startFrame = Value(startFrame),
       status = Value(status),
       startedAt = Value(startedAt),
       updatedAt = Value(updatedAt);
  static Insertable<RollRow> custom({
    Expression<String>? id,
    Expression<int>? number,
    Expression<String>? filmStock,
    Expression<String>? filmType,
    Expression<int>? boxIso,
    Expression<int>? pushThirds,
    Expression<String>? bodyId,
    Expression<String>? bodyMake,
    Expression<String>? bodyModel,
    Expression<String>? format,
    Expression<int>? size,
    Expression<String>? startFrame,
    Expression<String>? notes,
    Expression<int>? latitudeUnderHalves,
    Expression<int>? latitudeOverHalves,
    Expression<String>? status,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? finishedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (number != null) 'number': number,
      if (filmStock != null) 'film_stock': filmStock,
      if (filmType != null) 'film_type': filmType,
      if (boxIso != null) 'box_iso': boxIso,
      if (pushThirds != null) 'push_thirds': pushThirds,
      if (bodyId != null) 'body_id': bodyId,
      if (bodyMake != null) 'body_make': bodyMake,
      if (bodyModel != null) 'body_model': bodyModel,
      if (format != null) 'format': format,
      if (size != null) 'size': size,
      if (startFrame != null) 'start_frame': startFrame,
      if (notes != null) 'notes': notes,
      if (latitudeUnderHalves != null)
        'latitude_under_halves': latitudeUnderHalves,
      if (latitudeOverHalves != null)
        'latitude_over_halves': latitudeOverHalves,
      if (status != null) 'status': status,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RollsCompanion copyWith({
    Value<String>? id,
    Value<int>? number,
    Value<String>? filmStock,
    Value<String>? filmType,
    Value<int>? boxIso,
    Value<int>? pushThirds,
    Value<String?>? bodyId,
    Value<String>? bodyMake,
    Value<String>? bodyModel,
    Value<String>? format,
    Value<int>? size,
    Value<String>? startFrame,
    Value<String>? notes,
    Value<int?>? latitudeUnderHalves,
    Value<int?>? latitudeOverHalves,
    Value<String>? status,
    Value<DateTime>? startedAt,
    Value<DateTime?>? finishedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return RollsCompanion(
      id: id ?? this.id,
      number: number ?? this.number,
      filmStock: filmStock ?? this.filmStock,
      filmType: filmType ?? this.filmType,
      boxIso: boxIso ?? this.boxIso,
      pushThirds: pushThirds ?? this.pushThirds,
      bodyId: bodyId ?? this.bodyId,
      bodyMake: bodyMake ?? this.bodyMake,
      bodyModel: bodyModel ?? this.bodyModel,
      format: format ?? this.format,
      size: size ?? this.size,
      startFrame: startFrame ?? this.startFrame,
      notes: notes ?? this.notes,
      latitudeUnderHalves: latitudeUnderHalves ?? this.latitudeUnderHalves,
      latitudeOverHalves: latitudeOverHalves ?? this.latitudeOverHalves,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (number.present) {
      map['number'] = Variable<int>(number.value);
    }
    if (filmStock.present) {
      map['film_stock'] = Variable<String>(filmStock.value);
    }
    if (filmType.present) {
      map['film_type'] = Variable<String>(filmType.value);
    }
    if (boxIso.present) {
      map['box_iso'] = Variable<int>(boxIso.value);
    }
    if (pushThirds.present) {
      map['push_thirds'] = Variable<int>(pushThirds.value);
    }
    if (bodyId.present) {
      map['body_id'] = Variable<String>(bodyId.value);
    }
    if (bodyMake.present) {
      map['body_make'] = Variable<String>(bodyMake.value);
    }
    if (bodyModel.present) {
      map['body_model'] = Variable<String>(bodyModel.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (startFrame.present) {
      map['start_frame'] = Variable<String>(startFrame.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (latitudeUnderHalves.present) {
      map['latitude_under_halves'] = Variable<int>(latitudeUnderHalves.value);
    }
    if (latitudeOverHalves.present) {
      map['latitude_over_halves'] = Variable<int>(latitudeOverHalves.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RollsCompanion(')
          ..write('id: $id, ')
          ..write('number: $number, ')
          ..write('filmStock: $filmStock, ')
          ..write('filmType: $filmType, ')
          ..write('boxIso: $boxIso, ')
          ..write('pushThirds: $pushThirds, ')
          ..write('bodyId: $bodyId, ')
          ..write('bodyMake: $bodyMake, ')
          ..write('bodyModel: $bodyModel, ')
          ..write('format: $format, ')
          ..write('size: $size, ')
          ..write('startFrame: $startFrame, ')
          ..write('notes: $notes, ')
          ..write('latitudeUnderHalves: $latitudeUnderHalves, ')
          ..write('latitudeOverHalves: $latitudeOverHalves, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FramesTable extends Frames with TableInfo<$FramesTable, FrameRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FramesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _apertureMeta = const VerificationMeta(
    'aperture',
  );
  @override
  late final GeneratedColumn<double> aperture = GeneratedColumn<double>(
    'aperture',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shutterMeta = const VerificationMeta(
    'shutter',
  );
  @override
  late final GeneratedColumn<String> shutter = GeneratedColumn<String>(
    'shutter',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exposureTimeMeta = const VerificationMeta(
    'exposureTime',
  );
  @override
  late final GeneratedColumn<double> exposureTime = GeneratedColumn<double>(
    'exposure_time',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isoMeta = const VerificationMeta('iso');
  @override
  late final GeneratedColumn<int> iso = GeneratedColumn<int>(
    'iso',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lensIdMeta = const VerificationMeta('lensId');
  @override
  late final GeneratedColumn<String> lensId = GeneratedColumn<String>(
    'lens_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lensMakeMeta = const VerificationMeta(
    'lensMake',
  );
  @override
  late final GeneratedColumn<String> lensMake = GeneratedColumn<String>(
    'lens_make',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lensNameMeta = const VerificationMeta(
    'lensName',
  );
  @override
  late final GeneratedColumn<String> lensName = GeneratedColumn<String>(
    'lens_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _focalMeta = const VerificationMeta('focal');
  @override
  late final GeneratedColumn<double> focal = GeneratedColumn<double>(
    'focal',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _meteredEvMeta = const VerificationMeta(
    'meteredEv',
  );
  @override
  late final GeneratedColumn<double> meteredEv = GeneratedColumn<double>(
    'metered_ev',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _offsetStopsMeta = const VerificationMeta(
    'offsetStops',
  );
  @override
  late final GeneratedColumn<double> offsetStops = GeneratedColumn<double>(
    'offset_stops',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _areaMeta = const VerificationMeta('area');
  @override
  late final GeneratedColumn<String> area = GeneratedColumn<String>(
    'area',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _takenAtMeta = const VerificationMeta(
    'takenAt',
  );
  @override
  late final GeneratedColumn<DateTime> takenAt = GeneratedColumn<DateTime>(
    'taken_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _utcOffsetMinutesMeta = const VerificationMeta(
    'utcOffsetMinutes',
  );
  @override
  late final GeneratedColumn<int> utcOffsetMinutes = GeneratedColumn<int>(
    'utc_offset_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationAccuracyMeta = const VerificationMeta(
    'locationAccuracy',
  );
  @override
  late final GeneratedColumn<double> locationAccuracy = GeneratedColumn<double>(
    'location_accuracy',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snapshotMeta = const VerificationMeta(
    'snapshot',
  );
  @override
  late final GeneratedColumn<String> snapshot = GeneratedColumn<String>(
    'snapshot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rollIdMeta = const VerificationMeta('rollId');
  @override
  late final GeneratedColumn<String> rollId = GeneratedColumn<String>(
    'roll_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES rolls (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<int> number = GeneratedColumn<int>(
    'number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    mode,
    aperture,
    shutter,
    exposureTime,
    iso,
    lensId,
    lensMake,
    lensName,
    focal,
    meteredEv,
    offsetStops,
    area,
    takenAt,
    utcOffsetMinutes,
    note,
    latitude,
    longitude,
    locationAccuracy,
    snapshot,
    updatedAt,
    id,
    rollId,
    position,
    number,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'frames';
  @override
  VerificationContext validateIntegrity(
    Insertable<FrameRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    }
    if (data.containsKey('aperture')) {
      context.handle(
        _apertureMeta,
        aperture.isAcceptableOrUnknown(data['aperture']!, _apertureMeta),
      );
    }
    if (data.containsKey('shutter')) {
      context.handle(
        _shutterMeta,
        shutter.isAcceptableOrUnknown(data['shutter']!, _shutterMeta),
      );
    }
    if (data.containsKey('exposure_time')) {
      context.handle(
        _exposureTimeMeta,
        exposureTime.isAcceptableOrUnknown(
          data['exposure_time']!,
          _exposureTimeMeta,
        ),
      );
    }
    if (data.containsKey('iso')) {
      context.handle(
        _isoMeta,
        iso.isAcceptableOrUnknown(data['iso']!, _isoMeta),
      );
    }
    if (data.containsKey('lens_id')) {
      context.handle(
        _lensIdMeta,
        lensId.isAcceptableOrUnknown(data['lens_id']!, _lensIdMeta),
      );
    }
    if (data.containsKey('lens_make')) {
      context.handle(
        _lensMakeMeta,
        lensMake.isAcceptableOrUnknown(data['lens_make']!, _lensMakeMeta),
      );
    }
    if (data.containsKey('lens_name')) {
      context.handle(
        _lensNameMeta,
        lensName.isAcceptableOrUnknown(data['lens_name']!, _lensNameMeta),
      );
    }
    if (data.containsKey('focal')) {
      context.handle(
        _focalMeta,
        focal.isAcceptableOrUnknown(data['focal']!, _focalMeta),
      );
    }
    if (data.containsKey('metered_ev')) {
      context.handle(
        _meteredEvMeta,
        meteredEv.isAcceptableOrUnknown(data['metered_ev']!, _meteredEvMeta),
      );
    }
    if (data.containsKey('offset_stops')) {
      context.handle(
        _offsetStopsMeta,
        offsetStops.isAcceptableOrUnknown(
          data['offset_stops']!,
          _offsetStopsMeta,
        ),
      );
    }
    if (data.containsKey('area')) {
      context.handle(
        _areaMeta,
        area.isAcceptableOrUnknown(data['area']!, _areaMeta),
      );
    }
    if (data.containsKey('taken_at')) {
      context.handle(
        _takenAtMeta,
        takenAt.isAcceptableOrUnknown(data['taken_at']!, _takenAtMeta),
      );
    }
    if (data.containsKey('utc_offset_minutes')) {
      context.handle(
        _utcOffsetMinutesMeta,
        utcOffsetMinutes.isAcceptableOrUnknown(
          data['utc_offset_minutes']!,
          _utcOffsetMinutesMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('location_accuracy')) {
      context.handle(
        _locationAccuracyMeta,
        locationAccuracy.isAcceptableOrUnknown(
          data['location_accuracy']!,
          _locationAccuracyMeta,
        ),
      );
    }
    if (data.containsKey('snapshot')) {
      context.handle(
        _snapshotMeta,
        snapshot.isAcceptableOrUnknown(data['snapshot']!, _snapshotMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('roll_id')) {
      context.handle(
        _rollIdMeta,
        rollId.isAcceptableOrUnknown(data['roll_id']!, _rollIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rollIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FrameRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FrameRow(
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      ),
      aperture: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}aperture'],
      ),
      shutter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shutter'],
      ),
      exposureTime: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}exposure_time'],
      ),
      iso: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}iso'],
      ),
      lensId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lens_id'],
      ),
      lensMake: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lens_make'],
      ),
      lensName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lens_name'],
      ),
      focal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}focal'],
      ),
      meteredEv: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}metered_ev'],
      ),
      offsetStops: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}offset_stops'],
      ),
      area: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}area'],
      ),
      takenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}taken_at'],
      ),
      utcOffsetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}utc_offset_minutes'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      locationAccuracy: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}location_accuracy'],
      ),
      snapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      rollId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}roll_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}number'],
      )!,
    );
  }

  @override
  $FramesTable createAlias(String alias) {
    return $FramesTable(attachedDatabase, alias);
  }
}

class FrameRow extends DataClass implements Insertable<FrameRow> {
  /// MeterMode.name
  final String? mode;
  final double? aperture;
  final String? shutter;
  final double? exposureTime;
  final int? iso;
  final String? lensId;
  final String? lensMake;
  final String? lensName;
  final double? focal;
  final double? meteredEv;
  final double? offsetStops;

  /// MeterArea.name
  final String? area;
  final DateTime? takenAt;
  final int? utcOffsetMinutes;
  final String? note;
  final double? latitude;
  final double? longitude;
  final double? locationAccuracy;

  /// Snapshot file name (`<uuid>.jpg`), never a path.
  final String? snapshot;
  final DateTime updatedAt;
  final String id;
  final String rollId;
  final int position;
  final int number;
  const FrameRow({
    this.mode,
    this.aperture,
    this.shutter,
    this.exposureTime,
    this.iso,
    this.lensId,
    this.lensMake,
    this.lensName,
    this.focal,
    this.meteredEv,
    this.offsetStops,
    this.area,
    this.takenAt,
    this.utcOffsetMinutes,
    this.note,
    this.latitude,
    this.longitude,
    this.locationAccuracy,
    this.snapshot,
    required this.updatedAt,
    required this.id,
    required this.rollId,
    required this.position,
    required this.number,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || mode != null) {
      map['mode'] = Variable<String>(mode);
    }
    if (!nullToAbsent || aperture != null) {
      map['aperture'] = Variable<double>(aperture);
    }
    if (!nullToAbsent || shutter != null) {
      map['shutter'] = Variable<String>(shutter);
    }
    if (!nullToAbsent || exposureTime != null) {
      map['exposure_time'] = Variable<double>(exposureTime);
    }
    if (!nullToAbsent || iso != null) {
      map['iso'] = Variable<int>(iso);
    }
    if (!nullToAbsent || lensId != null) {
      map['lens_id'] = Variable<String>(lensId);
    }
    if (!nullToAbsent || lensMake != null) {
      map['lens_make'] = Variable<String>(lensMake);
    }
    if (!nullToAbsent || lensName != null) {
      map['lens_name'] = Variable<String>(lensName);
    }
    if (!nullToAbsent || focal != null) {
      map['focal'] = Variable<double>(focal);
    }
    if (!nullToAbsent || meteredEv != null) {
      map['metered_ev'] = Variable<double>(meteredEv);
    }
    if (!nullToAbsent || offsetStops != null) {
      map['offset_stops'] = Variable<double>(offsetStops);
    }
    if (!nullToAbsent || area != null) {
      map['area'] = Variable<String>(area);
    }
    if (!nullToAbsent || takenAt != null) {
      map['taken_at'] = Variable<DateTime>(takenAt);
    }
    if (!nullToAbsent || utcOffsetMinutes != null) {
      map['utc_offset_minutes'] = Variable<int>(utcOffsetMinutes);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    if (!nullToAbsent || locationAccuracy != null) {
      map['location_accuracy'] = Variable<double>(locationAccuracy);
    }
    if (!nullToAbsent || snapshot != null) {
      map['snapshot'] = Variable<String>(snapshot);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['id'] = Variable<String>(id);
    map['roll_id'] = Variable<String>(rollId);
    map['position'] = Variable<int>(position);
    map['number'] = Variable<int>(number);
    return map;
  }

  FramesCompanion toCompanion(bool nullToAbsent) {
    return FramesCompanion(
      mode: mode == null && nullToAbsent ? const Value.absent() : Value(mode),
      aperture: aperture == null && nullToAbsent
          ? const Value.absent()
          : Value(aperture),
      shutter: shutter == null && nullToAbsent
          ? const Value.absent()
          : Value(shutter),
      exposureTime: exposureTime == null && nullToAbsent
          ? const Value.absent()
          : Value(exposureTime),
      iso: iso == null && nullToAbsent ? const Value.absent() : Value(iso),
      lensId: lensId == null && nullToAbsent
          ? const Value.absent()
          : Value(lensId),
      lensMake: lensMake == null && nullToAbsent
          ? const Value.absent()
          : Value(lensMake),
      lensName: lensName == null && nullToAbsent
          ? const Value.absent()
          : Value(lensName),
      focal: focal == null && nullToAbsent
          ? const Value.absent()
          : Value(focal),
      meteredEv: meteredEv == null && nullToAbsent
          ? const Value.absent()
          : Value(meteredEv),
      offsetStops: offsetStops == null && nullToAbsent
          ? const Value.absent()
          : Value(offsetStops),
      area: area == null && nullToAbsent ? const Value.absent() : Value(area),
      takenAt: takenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(takenAt),
      utcOffsetMinutes: utcOffsetMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(utcOffsetMinutes),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      locationAccuracy: locationAccuracy == null && nullToAbsent
          ? const Value.absent()
          : Value(locationAccuracy),
      snapshot: snapshot == null && nullToAbsent
          ? const Value.absent()
          : Value(snapshot),
      updatedAt: Value(updatedAt),
      id: Value(id),
      rollId: Value(rollId),
      position: Value(position),
      number: Value(number),
    );
  }

  factory FrameRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FrameRow(
      mode: serializer.fromJson<String?>(json['mode']),
      aperture: serializer.fromJson<double?>(json['aperture']),
      shutter: serializer.fromJson<String?>(json['shutter']),
      exposureTime: serializer.fromJson<double?>(json['exposureTime']),
      iso: serializer.fromJson<int?>(json['iso']),
      lensId: serializer.fromJson<String?>(json['lensId']),
      lensMake: serializer.fromJson<String?>(json['lensMake']),
      lensName: serializer.fromJson<String?>(json['lensName']),
      focal: serializer.fromJson<double?>(json['focal']),
      meteredEv: serializer.fromJson<double?>(json['meteredEv']),
      offsetStops: serializer.fromJson<double?>(json['offsetStops']),
      area: serializer.fromJson<String?>(json['area']),
      takenAt: serializer.fromJson<DateTime?>(json['takenAt']),
      utcOffsetMinutes: serializer.fromJson<int?>(json['utcOffsetMinutes']),
      note: serializer.fromJson<String?>(json['note']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      locationAccuracy: serializer.fromJson<double?>(json['locationAccuracy']),
      snapshot: serializer.fromJson<String?>(json['snapshot']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      id: serializer.fromJson<String>(json['id']),
      rollId: serializer.fromJson<String>(json['rollId']),
      position: serializer.fromJson<int>(json['position']),
      number: serializer.fromJson<int>(json['number']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mode': serializer.toJson<String?>(mode),
      'aperture': serializer.toJson<double?>(aperture),
      'shutter': serializer.toJson<String?>(shutter),
      'exposureTime': serializer.toJson<double?>(exposureTime),
      'iso': serializer.toJson<int?>(iso),
      'lensId': serializer.toJson<String?>(lensId),
      'lensMake': serializer.toJson<String?>(lensMake),
      'lensName': serializer.toJson<String?>(lensName),
      'focal': serializer.toJson<double?>(focal),
      'meteredEv': serializer.toJson<double?>(meteredEv),
      'offsetStops': serializer.toJson<double?>(offsetStops),
      'area': serializer.toJson<String?>(area),
      'takenAt': serializer.toJson<DateTime?>(takenAt),
      'utcOffsetMinutes': serializer.toJson<int?>(utcOffsetMinutes),
      'note': serializer.toJson<String?>(note),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'locationAccuracy': serializer.toJson<double?>(locationAccuracy),
      'snapshot': serializer.toJson<String?>(snapshot),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'id': serializer.toJson<String>(id),
      'rollId': serializer.toJson<String>(rollId),
      'position': serializer.toJson<int>(position),
      'number': serializer.toJson<int>(number),
    };
  }

  FrameRow copyWith({
    Value<String?> mode = const Value.absent(),
    Value<double?> aperture = const Value.absent(),
    Value<String?> shutter = const Value.absent(),
    Value<double?> exposureTime = const Value.absent(),
    Value<int?> iso = const Value.absent(),
    Value<String?> lensId = const Value.absent(),
    Value<String?> lensMake = const Value.absent(),
    Value<String?> lensName = const Value.absent(),
    Value<double?> focal = const Value.absent(),
    Value<double?> meteredEv = const Value.absent(),
    Value<double?> offsetStops = const Value.absent(),
    Value<String?> area = const Value.absent(),
    Value<DateTime?> takenAt = const Value.absent(),
    Value<int?> utcOffsetMinutes = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    Value<double?> locationAccuracy = const Value.absent(),
    Value<String?> snapshot = const Value.absent(),
    DateTime? updatedAt,
    String? id,
    String? rollId,
    int? position,
    int? number,
  }) => FrameRow(
    mode: mode.present ? mode.value : this.mode,
    aperture: aperture.present ? aperture.value : this.aperture,
    shutter: shutter.present ? shutter.value : this.shutter,
    exposureTime: exposureTime.present ? exposureTime.value : this.exposureTime,
    iso: iso.present ? iso.value : this.iso,
    lensId: lensId.present ? lensId.value : this.lensId,
    lensMake: lensMake.present ? lensMake.value : this.lensMake,
    lensName: lensName.present ? lensName.value : this.lensName,
    focal: focal.present ? focal.value : this.focal,
    meteredEv: meteredEv.present ? meteredEv.value : this.meteredEv,
    offsetStops: offsetStops.present ? offsetStops.value : this.offsetStops,
    area: area.present ? area.value : this.area,
    takenAt: takenAt.present ? takenAt.value : this.takenAt,
    utcOffsetMinutes: utcOffsetMinutes.present
        ? utcOffsetMinutes.value
        : this.utcOffsetMinutes,
    note: note.present ? note.value : this.note,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    locationAccuracy: locationAccuracy.present
        ? locationAccuracy.value
        : this.locationAccuracy,
    snapshot: snapshot.present ? snapshot.value : this.snapshot,
    updatedAt: updatedAt ?? this.updatedAt,
    id: id ?? this.id,
    rollId: rollId ?? this.rollId,
    position: position ?? this.position,
    number: number ?? this.number,
  );
  FrameRow copyWithCompanion(FramesCompanion data) {
    return FrameRow(
      mode: data.mode.present ? data.mode.value : this.mode,
      aperture: data.aperture.present ? data.aperture.value : this.aperture,
      shutter: data.shutter.present ? data.shutter.value : this.shutter,
      exposureTime: data.exposureTime.present
          ? data.exposureTime.value
          : this.exposureTime,
      iso: data.iso.present ? data.iso.value : this.iso,
      lensId: data.lensId.present ? data.lensId.value : this.lensId,
      lensMake: data.lensMake.present ? data.lensMake.value : this.lensMake,
      lensName: data.lensName.present ? data.lensName.value : this.lensName,
      focal: data.focal.present ? data.focal.value : this.focal,
      meteredEv: data.meteredEv.present ? data.meteredEv.value : this.meteredEv,
      offsetStops: data.offsetStops.present
          ? data.offsetStops.value
          : this.offsetStops,
      area: data.area.present ? data.area.value : this.area,
      takenAt: data.takenAt.present ? data.takenAt.value : this.takenAt,
      utcOffsetMinutes: data.utcOffsetMinutes.present
          ? data.utcOffsetMinutes.value
          : this.utcOffsetMinutes,
      note: data.note.present ? data.note.value : this.note,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      locationAccuracy: data.locationAccuracy.present
          ? data.locationAccuracy.value
          : this.locationAccuracy,
      snapshot: data.snapshot.present ? data.snapshot.value : this.snapshot,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      id: data.id.present ? data.id.value : this.id,
      rollId: data.rollId.present ? data.rollId.value : this.rollId,
      position: data.position.present ? data.position.value : this.position,
      number: data.number.present ? data.number.value : this.number,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FrameRow(')
          ..write('mode: $mode, ')
          ..write('aperture: $aperture, ')
          ..write('shutter: $shutter, ')
          ..write('exposureTime: $exposureTime, ')
          ..write('iso: $iso, ')
          ..write('lensId: $lensId, ')
          ..write('lensMake: $lensMake, ')
          ..write('lensName: $lensName, ')
          ..write('focal: $focal, ')
          ..write('meteredEv: $meteredEv, ')
          ..write('offsetStops: $offsetStops, ')
          ..write('area: $area, ')
          ..write('takenAt: $takenAt, ')
          ..write('utcOffsetMinutes: $utcOffsetMinutes, ')
          ..write('note: $note, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('locationAccuracy: $locationAccuracy, ')
          ..write('snapshot: $snapshot, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('id: $id, ')
          ..write('rollId: $rollId, ')
          ..write('position: $position, ')
          ..write('number: $number')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    mode,
    aperture,
    shutter,
    exposureTime,
    iso,
    lensId,
    lensMake,
    lensName,
    focal,
    meteredEv,
    offsetStops,
    area,
    takenAt,
    utcOffsetMinutes,
    note,
    latitude,
    longitude,
    locationAccuracy,
    snapshot,
    updatedAt,
    id,
    rollId,
    position,
    number,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FrameRow &&
          other.mode == this.mode &&
          other.aperture == this.aperture &&
          other.shutter == this.shutter &&
          other.exposureTime == this.exposureTime &&
          other.iso == this.iso &&
          other.lensId == this.lensId &&
          other.lensMake == this.lensMake &&
          other.lensName == this.lensName &&
          other.focal == this.focal &&
          other.meteredEv == this.meteredEv &&
          other.offsetStops == this.offsetStops &&
          other.area == this.area &&
          other.takenAt == this.takenAt &&
          other.utcOffsetMinutes == this.utcOffsetMinutes &&
          other.note == this.note &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.locationAccuracy == this.locationAccuracy &&
          other.snapshot == this.snapshot &&
          other.updatedAt == this.updatedAt &&
          other.id == this.id &&
          other.rollId == this.rollId &&
          other.position == this.position &&
          other.number == this.number);
}

class FramesCompanion extends UpdateCompanion<FrameRow> {
  final Value<String?> mode;
  final Value<double?> aperture;
  final Value<String?> shutter;
  final Value<double?> exposureTime;
  final Value<int?> iso;
  final Value<String?> lensId;
  final Value<String?> lensMake;
  final Value<String?> lensName;
  final Value<double?> focal;
  final Value<double?> meteredEv;
  final Value<double?> offsetStops;
  final Value<String?> area;
  final Value<DateTime?> takenAt;
  final Value<int?> utcOffsetMinutes;
  final Value<String?> note;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<double?> locationAccuracy;
  final Value<String?> snapshot;
  final Value<DateTime> updatedAt;
  final Value<String> id;
  final Value<String> rollId;
  final Value<int> position;
  final Value<int> number;
  final Value<int> rowid;
  const FramesCompanion({
    this.mode = const Value.absent(),
    this.aperture = const Value.absent(),
    this.shutter = const Value.absent(),
    this.exposureTime = const Value.absent(),
    this.iso = const Value.absent(),
    this.lensId = const Value.absent(),
    this.lensMake = const Value.absent(),
    this.lensName = const Value.absent(),
    this.focal = const Value.absent(),
    this.meteredEv = const Value.absent(),
    this.offsetStops = const Value.absent(),
    this.area = const Value.absent(),
    this.takenAt = const Value.absent(),
    this.utcOffsetMinutes = const Value.absent(),
    this.note = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.locationAccuracy = const Value.absent(),
    this.snapshot = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.rollId = const Value.absent(),
    this.position = const Value.absent(),
    this.number = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FramesCompanion.insert({
    this.mode = const Value.absent(),
    this.aperture = const Value.absent(),
    this.shutter = const Value.absent(),
    this.exposureTime = const Value.absent(),
    this.iso = const Value.absent(),
    this.lensId = const Value.absent(),
    this.lensMake = const Value.absent(),
    this.lensName = const Value.absent(),
    this.focal = const Value.absent(),
    this.meteredEv = const Value.absent(),
    this.offsetStops = const Value.absent(),
    this.area = const Value.absent(),
    this.takenAt = const Value.absent(),
    this.utcOffsetMinutes = const Value.absent(),
    this.note = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.locationAccuracy = const Value.absent(),
    this.snapshot = const Value.absent(),
    required DateTime updatedAt,
    required String id,
    required String rollId,
    required int position,
    required int number,
    this.rowid = const Value.absent(),
  }) : updatedAt = Value(updatedAt),
       id = Value(id),
       rollId = Value(rollId),
       position = Value(position),
       number = Value(number);
  static Insertable<FrameRow> custom({
    Expression<String>? mode,
    Expression<double>? aperture,
    Expression<String>? shutter,
    Expression<double>? exposureTime,
    Expression<int>? iso,
    Expression<String>? lensId,
    Expression<String>? lensMake,
    Expression<String>? lensName,
    Expression<double>? focal,
    Expression<double>? meteredEv,
    Expression<double>? offsetStops,
    Expression<String>? area,
    Expression<DateTime>? takenAt,
    Expression<int>? utcOffsetMinutes,
    Expression<String>? note,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? locationAccuracy,
    Expression<String>? snapshot,
    Expression<DateTime>? updatedAt,
    Expression<String>? id,
    Expression<String>? rollId,
    Expression<int>? position,
    Expression<int>? number,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mode != null) 'mode': mode,
      if (aperture != null) 'aperture': aperture,
      if (shutter != null) 'shutter': shutter,
      if (exposureTime != null) 'exposure_time': exposureTime,
      if (iso != null) 'iso': iso,
      if (lensId != null) 'lens_id': lensId,
      if (lensMake != null) 'lens_make': lensMake,
      if (lensName != null) 'lens_name': lensName,
      if (focal != null) 'focal': focal,
      if (meteredEv != null) 'metered_ev': meteredEv,
      if (offsetStops != null) 'offset_stops': offsetStops,
      if (area != null) 'area': area,
      if (takenAt != null) 'taken_at': takenAt,
      if (utcOffsetMinutes != null) 'utc_offset_minutes': utcOffsetMinutes,
      if (note != null) 'note': note,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (locationAccuracy != null) 'location_accuracy': locationAccuracy,
      if (snapshot != null) 'snapshot': snapshot,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (id != null) 'id': id,
      if (rollId != null) 'roll_id': rollId,
      if (position != null) 'position': position,
      if (number != null) 'number': number,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FramesCompanion copyWith({
    Value<String?>? mode,
    Value<double?>? aperture,
    Value<String?>? shutter,
    Value<double?>? exposureTime,
    Value<int?>? iso,
    Value<String?>? lensId,
    Value<String?>? lensMake,
    Value<String?>? lensName,
    Value<double?>? focal,
    Value<double?>? meteredEv,
    Value<double?>? offsetStops,
    Value<String?>? area,
    Value<DateTime?>? takenAt,
    Value<int?>? utcOffsetMinutes,
    Value<String?>? note,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<double?>? locationAccuracy,
    Value<String?>? snapshot,
    Value<DateTime>? updatedAt,
    Value<String>? id,
    Value<String>? rollId,
    Value<int>? position,
    Value<int>? number,
    Value<int>? rowid,
  }) {
    return FramesCompanion(
      mode: mode ?? this.mode,
      aperture: aperture ?? this.aperture,
      shutter: shutter ?? this.shutter,
      exposureTime: exposureTime ?? this.exposureTime,
      iso: iso ?? this.iso,
      lensId: lensId ?? this.lensId,
      lensMake: lensMake ?? this.lensMake,
      lensName: lensName ?? this.lensName,
      focal: focal ?? this.focal,
      meteredEv: meteredEv ?? this.meteredEv,
      offsetStops: offsetStops ?? this.offsetStops,
      area: area ?? this.area,
      takenAt: takenAt ?? this.takenAt,
      utcOffsetMinutes: utcOffsetMinutes ?? this.utcOffsetMinutes,
      note: note ?? this.note,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationAccuracy: locationAccuracy ?? this.locationAccuracy,
      snapshot: snapshot ?? this.snapshot,
      updatedAt: updatedAt ?? this.updatedAt,
      id: id ?? this.id,
      rollId: rollId ?? this.rollId,
      position: position ?? this.position,
      number: number ?? this.number,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (aperture.present) {
      map['aperture'] = Variable<double>(aperture.value);
    }
    if (shutter.present) {
      map['shutter'] = Variable<String>(shutter.value);
    }
    if (exposureTime.present) {
      map['exposure_time'] = Variable<double>(exposureTime.value);
    }
    if (iso.present) {
      map['iso'] = Variable<int>(iso.value);
    }
    if (lensId.present) {
      map['lens_id'] = Variable<String>(lensId.value);
    }
    if (lensMake.present) {
      map['lens_make'] = Variable<String>(lensMake.value);
    }
    if (lensName.present) {
      map['lens_name'] = Variable<String>(lensName.value);
    }
    if (focal.present) {
      map['focal'] = Variable<double>(focal.value);
    }
    if (meteredEv.present) {
      map['metered_ev'] = Variable<double>(meteredEv.value);
    }
    if (offsetStops.present) {
      map['offset_stops'] = Variable<double>(offsetStops.value);
    }
    if (area.present) {
      map['area'] = Variable<String>(area.value);
    }
    if (takenAt.present) {
      map['taken_at'] = Variable<DateTime>(takenAt.value);
    }
    if (utcOffsetMinutes.present) {
      map['utc_offset_minutes'] = Variable<int>(utcOffsetMinutes.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (locationAccuracy.present) {
      map['location_accuracy'] = Variable<double>(locationAccuracy.value);
    }
    if (snapshot.present) {
      map['snapshot'] = Variable<String>(snapshot.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (rollId.present) {
      map['roll_id'] = Variable<String>(rollId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (number.present) {
      map['number'] = Variable<int>(number.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FramesCompanion(')
          ..write('mode: $mode, ')
          ..write('aperture: $aperture, ')
          ..write('shutter: $shutter, ')
          ..write('exposureTime: $exposureTime, ')
          ..write('iso: $iso, ')
          ..write('lensId: $lensId, ')
          ..write('lensMake: $lensMake, ')
          ..write('lensName: $lensName, ')
          ..write('focal: $focal, ')
          ..write('meteredEv: $meteredEv, ')
          ..write('offsetStops: $offsetStops, ')
          ..write('area: $area, ')
          ..write('takenAt: $takenAt, ')
          ..write('utcOffsetMinutes: $utcOffsetMinutes, ')
          ..write('note: $note, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('locationAccuracy: $locationAccuracy, ')
          ..write('snapshot: $snapshot, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('id: $id, ')
          ..write('rollId: $rollId, ')
          ..write('position: $position, ')
          ..write('number: $number, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavedReadingsTable extends SavedReadings
    with TableInfo<$SavedReadingsTable, SavedReadingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedReadingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _apertureMeta = const VerificationMeta(
    'aperture',
  );
  @override
  late final GeneratedColumn<double> aperture = GeneratedColumn<double>(
    'aperture',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shutterMeta = const VerificationMeta(
    'shutter',
  );
  @override
  late final GeneratedColumn<String> shutter = GeneratedColumn<String>(
    'shutter',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exposureTimeMeta = const VerificationMeta(
    'exposureTime',
  );
  @override
  late final GeneratedColumn<double> exposureTime = GeneratedColumn<double>(
    'exposure_time',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isoMeta = const VerificationMeta('iso');
  @override
  late final GeneratedColumn<int> iso = GeneratedColumn<int>(
    'iso',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lensIdMeta = const VerificationMeta('lensId');
  @override
  late final GeneratedColumn<String> lensId = GeneratedColumn<String>(
    'lens_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lensMakeMeta = const VerificationMeta(
    'lensMake',
  );
  @override
  late final GeneratedColumn<String> lensMake = GeneratedColumn<String>(
    'lens_make',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lensNameMeta = const VerificationMeta(
    'lensName',
  );
  @override
  late final GeneratedColumn<String> lensName = GeneratedColumn<String>(
    'lens_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _focalMeta = const VerificationMeta('focal');
  @override
  late final GeneratedColumn<double> focal = GeneratedColumn<double>(
    'focal',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _meteredEvMeta = const VerificationMeta(
    'meteredEv',
  );
  @override
  late final GeneratedColumn<double> meteredEv = GeneratedColumn<double>(
    'metered_ev',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _offsetStopsMeta = const VerificationMeta(
    'offsetStops',
  );
  @override
  late final GeneratedColumn<double> offsetStops = GeneratedColumn<double>(
    'offset_stops',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _areaMeta = const VerificationMeta('area');
  @override
  late final GeneratedColumn<String> area = GeneratedColumn<String>(
    'area',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _takenAtMeta = const VerificationMeta(
    'takenAt',
  );
  @override
  late final GeneratedColumn<DateTime> takenAt = GeneratedColumn<DateTime>(
    'taken_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _utcOffsetMinutesMeta = const VerificationMeta(
    'utcOffsetMinutes',
  );
  @override
  late final GeneratedColumn<int> utcOffsetMinutes = GeneratedColumn<int>(
    'utc_offset_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationAccuracyMeta = const VerificationMeta(
    'locationAccuracy',
  );
  @override
  late final GeneratedColumn<double> locationAccuracy = GeneratedColumn<double>(
    'location_accuracy',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snapshotMeta = const VerificationMeta(
    'snapshot',
  );
  @override
  late final GeneratedColumn<String> snapshot = GeneratedColumn<String>(
    'snapshot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyIdMeta = const VerificationMeta('bodyId');
  @override
  late final GeneratedColumn<String> bodyId = GeneratedColumn<String>(
    'body_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyMakeMeta = const VerificationMeta(
    'bodyMake',
  );
  @override
  late final GeneratedColumn<String> bodyMake = GeneratedColumn<String>(
    'body_make',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyModelMeta = const VerificationMeta(
    'bodyModel',
  );
  @override
  late final GeneratedColumn<String> bodyModel = GeneratedColumn<String>(
    'body_model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    mode,
    aperture,
    shutter,
    exposureTime,
    iso,
    lensId,
    lensMake,
    lensName,
    focal,
    meteredEv,
    offsetStops,
    area,
    takenAt,
    utcOffsetMinutes,
    note,
    latitude,
    longitude,
    locationAccuracy,
    snapshot,
    updatedAt,
    id,
    bodyId,
    bodyMake,
    bodyModel,
    format,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_readings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedReadingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    }
    if (data.containsKey('aperture')) {
      context.handle(
        _apertureMeta,
        aperture.isAcceptableOrUnknown(data['aperture']!, _apertureMeta),
      );
    }
    if (data.containsKey('shutter')) {
      context.handle(
        _shutterMeta,
        shutter.isAcceptableOrUnknown(data['shutter']!, _shutterMeta),
      );
    }
    if (data.containsKey('exposure_time')) {
      context.handle(
        _exposureTimeMeta,
        exposureTime.isAcceptableOrUnknown(
          data['exposure_time']!,
          _exposureTimeMeta,
        ),
      );
    }
    if (data.containsKey('iso')) {
      context.handle(
        _isoMeta,
        iso.isAcceptableOrUnknown(data['iso']!, _isoMeta),
      );
    }
    if (data.containsKey('lens_id')) {
      context.handle(
        _lensIdMeta,
        lensId.isAcceptableOrUnknown(data['lens_id']!, _lensIdMeta),
      );
    }
    if (data.containsKey('lens_make')) {
      context.handle(
        _lensMakeMeta,
        lensMake.isAcceptableOrUnknown(data['lens_make']!, _lensMakeMeta),
      );
    }
    if (data.containsKey('lens_name')) {
      context.handle(
        _lensNameMeta,
        lensName.isAcceptableOrUnknown(data['lens_name']!, _lensNameMeta),
      );
    }
    if (data.containsKey('focal')) {
      context.handle(
        _focalMeta,
        focal.isAcceptableOrUnknown(data['focal']!, _focalMeta),
      );
    }
    if (data.containsKey('metered_ev')) {
      context.handle(
        _meteredEvMeta,
        meteredEv.isAcceptableOrUnknown(data['metered_ev']!, _meteredEvMeta),
      );
    }
    if (data.containsKey('offset_stops')) {
      context.handle(
        _offsetStopsMeta,
        offsetStops.isAcceptableOrUnknown(
          data['offset_stops']!,
          _offsetStopsMeta,
        ),
      );
    }
    if (data.containsKey('area')) {
      context.handle(
        _areaMeta,
        area.isAcceptableOrUnknown(data['area']!, _areaMeta),
      );
    }
    if (data.containsKey('taken_at')) {
      context.handle(
        _takenAtMeta,
        takenAt.isAcceptableOrUnknown(data['taken_at']!, _takenAtMeta),
      );
    }
    if (data.containsKey('utc_offset_minutes')) {
      context.handle(
        _utcOffsetMinutesMeta,
        utcOffsetMinutes.isAcceptableOrUnknown(
          data['utc_offset_minutes']!,
          _utcOffsetMinutesMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('location_accuracy')) {
      context.handle(
        _locationAccuracyMeta,
        locationAccuracy.isAcceptableOrUnknown(
          data['location_accuracy']!,
          _locationAccuracyMeta,
        ),
      );
    }
    if (data.containsKey('snapshot')) {
      context.handle(
        _snapshotMeta,
        snapshot.isAcceptableOrUnknown(data['snapshot']!, _snapshotMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('body_id')) {
      context.handle(
        _bodyIdMeta,
        bodyId.isAcceptableOrUnknown(data['body_id']!, _bodyIdMeta),
      );
    }
    if (data.containsKey('body_make')) {
      context.handle(
        _bodyMakeMeta,
        bodyMake.isAcceptableOrUnknown(data['body_make']!, _bodyMakeMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMakeMeta);
    }
    if (data.containsKey('body_model')) {
      context.handle(
        _bodyModelMeta,
        bodyModel.isAcceptableOrUnknown(data['body_model']!, _bodyModelMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyModelMeta);
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedReadingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedReadingRow(
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      ),
      aperture: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}aperture'],
      ),
      shutter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shutter'],
      ),
      exposureTime: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}exposure_time'],
      ),
      iso: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}iso'],
      ),
      lensId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lens_id'],
      ),
      lensMake: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lens_make'],
      ),
      lensName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lens_name'],
      ),
      focal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}focal'],
      ),
      meteredEv: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}metered_ev'],
      ),
      offsetStops: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}offset_stops'],
      ),
      area: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}area'],
      ),
      takenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}taken_at'],
      ),
      utcOffsetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}utc_offset_minutes'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      locationAccuracy: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}location_accuracy'],
      ),
      snapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bodyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_id'],
      ),
      bodyMake: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_make'],
      )!,
      bodyModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_model'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
    );
  }

  @override
  $SavedReadingsTable createAlias(String alias) {
    return $SavedReadingsTable(attachedDatabase, alias);
  }
}

class SavedReadingRow extends DataClass implements Insertable<SavedReadingRow> {
  /// MeterMode.name
  final String? mode;
  final double? aperture;
  final String? shutter;
  final double? exposureTime;
  final int? iso;
  final String? lensId;
  final String? lensMake;
  final String? lensName;
  final double? focal;
  final double? meteredEv;
  final double? offsetStops;

  /// MeterArea.name
  final String? area;
  final DateTime? takenAt;
  final int? utcOffsetMinutes;
  final String? note;
  final double? latitude;
  final double? longitude;
  final double? locationAccuracy;

  /// Snapshot file name (`<uuid>.jpg`), never a path.
  final String? snapshot;
  final DateTime updatedAt;
  final String id;
  final String? bodyId;
  final String bodyMake;
  final String bodyModel;

  /// FilmFormat.id
  final String format;
  const SavedReadingRow({
    this.mode,
    this.aperture,
    this.shutter,
    this.exposureTime,
    this.iso,
    this.lensId,
    this.lensMake,
    this.lensName,
    this.focal,
    this.meteredEv,
    this.offsetStops,
    this.area,
    this.takenAt,
    this.utcOffsetMinutes,
    this.note,
    this.latitude,
    this.longitude,
    this.locationAccuracy,
    this.snapshot,
    required this.updatedAt,
    required this.id,
    this.bodyId,
    required this.bodyMake,
    required this.bodyModel,
    required this.format,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || mode != null) {
      map['mode'] = Variable<String>(mode);
    }
    if (!nullToAbsent || aperture != null) {
      map['aperture'] = Variable<double>(aperture);
    }
    if (!nullToAbsent || shutter != null) {
      map['shutter'] = Variable<String>(shutter);
    }
    if (!nullToAbsent || exposureTime != null) {
      map['exposure_time'] = Variable<double>(exposureTime);
    }
    if (!nullToAbsent || iso != null) {
      map['iso'] = Variable<int>(iso);
    }
    if (!nullToAbsent || lensId != null) {
      map['lens_id'] = Variable<String>(lensId);
    }
    if (!nullToAbsent || lensMake != null) {
      map['lens_make'] = Variable<String>(lensMake);
    }
    if (!nullToAbsent || lensName != null) {
      map['lens_name'] = Variable<String>(lensName);
    }
    if (!nullToAbsent || focal != null) {
      map['focal'] = Variable<double>(focal);
    }
    if (!nullToAbsent || meteredEv != null) {
      map['metered_ev'] = Variable<double>(meteredEv);
    }
    if (!nullToAbsent || offsetStops != null) {
      map['offset_stops'] = Variable<double>(offsetStops);
    }
    if (!nullToAbsent || area != null) {
      map['area'] = Variable<String>(area);
    }
    if (!nullToAbsent || takenAt != null) {
      map['taken_at'] = Variable<DateTime>(takenAt);
    }
    if (!nullToAbsent || utcOffsetMinutes != null) {
      map['utc_offset_minutes'] = Variable<int>(utcOffsetMinutes);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    if (!nullToAbsent || locationAccuracy != null) {
      map['location_accuracy'] = Variable<double>(locationAccuracy);
    }
    if (!nullToAbsent || snapshot != null) {
      map['snapshot'] = Variable<String>(snapshot);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || bodyId != null) {
      map['body_id'] = Variable<String>(bodyId);
    }
    map['body_make'] = Variable<String>(bodyMake);
    map['body_model'] = Variable<String>(bodyModel);
    map['format'] = Variable<String>(format);
    return map;
  }

  SavedReadingsCompanion toCompanion(bool nullToAbsent) {
    return SavedReadingsCompanion(
      mode: mode == null && nullToAbsent ? const Value.absent() : Value(mode),
      aperture: aperture == null && nullToAbsent
          ? const Value.absent()
          : Value(aperture),
      shutter: shutter == null && nullToAbsent
          ? const Value.absent()
          : Value(shutter),
      exposureTime: exposureTime == null && nullToAbsent
          ? const Value.absent()
          : Value(exposureTime),
      iso: iso == null && nullToAbsent ? const Value.absent() : Value(iso),
      lensId: lensId == null && nullToAbsent
          ? const Value.absent()
          : Value(lensId),
      lensMake: lensMake == null && nullToAbsent
          ? const Value.absent()
          : Value(lensMake),
      lensName: lensName == null && nullToAbsent
          ? const Value.absent()
          : Value(lensName),
      focal: focal == null && nullToAbsent
          ? const Value.absent()
          : Value(focal),
      meteredEv: meteredEv == null && nullToAbsent
          ? const Value.absent()
          : Value(meteredEv),
      offsetStops: offsetStops == null && nullToAbsent
          ? const Value.absent()
          : Value(offsetStops),
      area: area == null && nullToAbsent ? const Value.absent() : Value(area),
      takenAt: takenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(takenAt),
      utcOffsetMinutes: utcOffsetMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(utcOffsetMinutes),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      locationAccuracy: locationAccuracy == null && nullToAbsent
          ? const Value.absent()
          : Value(locationAccuracy),
      snapshot: snapshot == null && nullToAbsent
          ? const Value.absent()
          : Value(snapshot),
      updatedAt: Value(updatedAt),
      id: Value(id),
      bodyId: bodyId == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyId),
      bodyMake: Value(bodyMake),
      bodyModel: Value(bodyModel),
      format: Value(format),
    );
  }

  factory SavedReadingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedReadingRow(
      mode: serializer.fromJson<String?>(json['mode']),
      aperture: serializer.fromJson<double?>(json['aperture']),
      shutter: serializer.fromJson<String?>(json['shutter']),
      exposureTime: serializer.fromJson<double?>(json['exposureTime']),
      iso: serializer.fromJson<int?>(json['iso']),
      lensId: serializer.fromJson<String?>(json['lensId']),
      lensMake: serializer.fromJson<String?>(json['lensMake']),
      lensName: serializer.fromJson<String?>(json['lensName']),
      focal: serializer.fromJson<double?>(json['focal']),
      meteredEv: serializer.fromJson<double?>(json['meteredEv']),
      offsetStops: serializer.fromJson<double?>(json['offsetStops']),
      area: serializer.fromJson<String?>(json['area']),
      takenAt: serializer.fromJson<DateTime?>(json['takenAt']),
      utcOffsetMinutes: serializer.fromJson<int?>(json['utcOffsetMinutes']),
      note: serializer.fromJson<String?>(json['note']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      locationAccuracy: serializer.fromJson<double?>(json['locationAccuracy']),
      snapshot: serializer.fromJson<String?>(json['snapshot']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      id: serializer.fromJson<String>(json['id']),
      bodyId: serializer.fromJson<String?>(json['bodyId']),
      bodyMake: serializer.fromJson<String>(json['bodyMake']),
      bodyModel: serializer.fromJson<String>(json['bodyModel']),
      format: serializer.fromJson<String>(json['format']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mode': serializer.toJson<String?>(mode),
      'aperture': serializer.toJson<double?>(aperture),
      'shutter': serializer.toJson<String?>(shutter),
      'exposureTime': serializer.toJson<double?>(exposureTime),
      'iso': serializer.toJson<int?>(iso),
      'lensId': serializer.toJson<String?>(lensId),
      'lensMake': serializer.toJson<String?>(lensMake),
      'lensName': serializer.toJson<String?>(lensName),
      'focal': serializer.toJson<double?>(focal),
      'meteredEv': serializer.toJson<double?>(meteredEv),
      'offsetStops': serializer.toJson<double?>(offsetStops),
      'area': serializer.toJson<String?>(area),
      'takenAt': serializer.toJson<DateTime?>(takenAt),
      'utcOffsetMinutes': serializer.toJson<int?>(utcOffsetMinutes),
      'note': serializer.toJson<String?>(note),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'locationAccuracy': serializer.toJson<double?>(locationAccuracy),
      'snapshot': serializer.toJson<String?>(snapshot),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'id': serializer.toJson<String>(id),
      'bodyId': serializer.toJson<String?>(bodyId),
      'bodyMake': serializer.toJson<String>(bodyMake),
      'bodyModel': serializer.toJson<String>(bodyModel),
      'format': serializer.toJson<String>(format),
    };
  }

  SavedReadingRow copyWith({
    Value<String?> mode = const Value.absent(),
    Value<double?> aperture = const Value.absent(),
    Value<String?> shutter = const Value.absent(),
    Value<double?> exposureTime = const Value.absent(),
    Value<int?> iso = const Value.absent(),
    Value<String?> lensId = const Value.absent(),
    Value<String?> lensMake = const Value.absent(),
    Value<String?> lensName = const Value.absent(),
    Value<double?> focal = const Value.absent(),
    Value<double?> meteredEv = const Value.absent(),
    Value<double?> offsetStops = const Value.absent(),
    Value<String?> area = const Value.absent(),
    Value<DateTime?> takenAt = const Value.absent(),
    Value<int?> utcOffsetMinutes = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    Value<double?> locationAccuracy = const Value.absent(),
    Value<String?> snapshot = const Value.absent(),
    DateTime? updatedAt,
    String? id,
    Value<String?> bodyId = const Value.absent(),
    String? bodyMake,
    String? bodyModel,
    String? format,
  }) => SavedReadingRow(
    mode: mode.present ? mode.value : this.mode,
    aperture: aperture.present ? aperture.value : this.aperture,
    shutter: shutter.present ? shutter.value : this.shutter,
    exposureTime: exposureTime.present ? exposureTime.value : this.exposureTime,
    iso: iso.present ? iso.value : this.iso,
    lensId: lensId.present ? lensId.value : this.lensId,
    lensMake: lensMake.present ? lensMake.value : this.lensMake,
    lensName: lensName.present ? lensName.value : this.lensName,
    focal: focal.present ? focal.value : this.focal,
    meteredEv: meteredEv.present ? meteredEv.value : this.meteredEv,
    offsetStops: offsetStops.present ? offsetStops.value : this.offsetStops,
    area: area.present ? area.value : this.area,
    takenAt: takenAt.present ? takenAt.value : this.takenAt,
    utcOffsetMinutes: utcOffsetMinutes.present
        ? utcOffsetMinutes.value
        : this.utcOffsetMinutes,
    note: note.present ? note.value : this.note,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    locationAccuracy: locationAccuracy.present
        ? locationAccuracy.value
        : this.locationAccuracy,
    snapshot: snapshot.present ? snapshot.value : this.snapshot,
    updatedAt: updatedAt ?? this.updatedAt,
    id: id ?? this.id,
    bodyId: bodyId.present ? bodyId.value : this.bodyId,
    bodyMake: bodyMake ?? this.bodyMake,
    bodyModel: bodyModel ?? this.bodyModel,
    format: format ?? this.format,
  );
  SavedReadingRow copyWithCompanion(SavedReadingsCompanion data) {
    return SavedReadingRow(
      mode: data.mode.present ? data.mode.value : this.mode,
      aperture: data.aperture.present ? data.aperture.value : this.aperture,
      shutter: data.shutter.present ? data.shutter.value : this.shutter,
      exposureTime: data.exposureTime.present
          ? data.exposureTime.value
          : this.exposureTime,
      iso: data.iso.present ? data.iso.value : this.iso,
      lensId: data.lensId.present ? data.lensId.value : this.lensId,
      lensMake: data.lensMake.present ? data.lensMake.value : this.lensMake,
      lensName: data.lensName.present ? data.lensName.value : this.lensName,
      focal: data.focal.present ? data.focal.value : this.focal,
      meteredEv: data.meteredEv.present ? data.meteredEv.value : this.meteredEv,
      offsetStops: data.offsetStops.present
          ? data.offsetStops.value
          : this.offsetStops,
      area: data.area.present ? data.area.value : this.area,
      takenAt: data.takenAt.present ? data.takenAt.value : this.takenAt,
      utcOffsetMinutes: data.utcOffsetMinutes.present
          ? data.utcOffsetMinutes.value
          : this.utcOffsetMinutes,
      note: data.note.present ? data.note.value : this.note,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      locationAccuracy: data.locationAccuracy.present
          ? data.locationAccuracy.value
          : this.locationAccuracy,
      snapshot: data.snapshot.present ? data.snapshot.value : this.snapshot,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      id: data.id.present ? data.id.value : this.id,
      bodyId: data.bodyId.present ? data.bodyId.value : this.bodyId,
      bodyMake: data.bodyMake.present ? data.bodyMake.value : this.bodyMake,
      bodyModel: data.bodyModel.present ? data.bodyModel.value : this.bodyModel,
      format: data.format.present ? data.format.value : this.format,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedReadingRow(')
          ..write('mode: $mode, ')
          ..write('aperture: $aperture, ')
          ..write('shutter: $shutter, ')
          ..write('exposureTime: $exposureTime, ')
          ..write('iso: $iso, ')
          ..write('lensId: $lensId, ')
          ..write('lensMake: $lensMake, ')
          ..write('lensName: $lensName, ')
          ..write('focal: $focal, ')
          ..write('meteredEv: $meteredEv, ')
          ..write('offsetStops: $offsetStops, ')
          ..write('area: $area, ')
          ..write('takenAt: $takenAt, ')
          ..write('utcOffsetMinutes: $utcOffsetMinutes, ')
          ..write('note: $note, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('locationAccuracy: $locationAccuracy, ')
          ..write('snapshot: $snapshot, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('id: $id, ')
          ..write('bodyId: $bodyId, ')
          ..write('bodyMake: $bodyMake, ')
          ..write('bodyModel: $bodyModel, ')
          ..write('format: $format')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    mode,
    aperture,
    shutter,
    exposureTime,
    iso,
    lensId,
    lensMake,
    lensName,
    focal,
    meteredEv,
    offsetStops,
    area,
    takenAt,
    utcOffsetMinutes,
    note,
    latitude,
    longitude,
    locationAccuracy,
    snapshot,
    updatedAt,
    id,
    bodyId,
    bodyMake,
    bodyModel,
    format,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedReadingRow &&
          other.mode == this.mode &&
          other.aperture == this.aperture &&
          other.shutter == this.shutter &&
          other.exposureTime == this.exposureTime &&
          other.iso == this.iso &&
          other.lensId == this.lensId &&
          other.lensMake == this.lensMake &&
          other.lensName == this.lensName &&
          other.focal == this.focal &&
          other.meteredEv == this.meteredEv &&
          other.offsetStops == this.offsetStops &&
          other.area == this.area &&
          other.takenAt == this.takenAt &&
          other.utcOffsetMinutes == this.utcOffsetMinutes &&
          other.note == this.note &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.locationAccuracy == this.locationAccuracy &&
          other.snapshot == this.snapshot &&
          other.updatedAt == this.updatedAt &&
          other.id == this.id &&
          other.bodyId == this.bodyId &&
          other.bodyMake == this.bodyMake &&
          other.bodyModel == this.bodyModel &&
          other.format == this.format);
}

class SavedReadingsCompanion extends UpdateCompanion<SavedReadingRow> {
  final Value<String?> mode;
  final Value<double?> aperture;
  final Value<String?> shutter;
  final Value<double?> exposureTime;
  final Value<int?> iso;
  final Value<String?> lensId;
  final Value<String?> lensMake;
  final Value<String?> lensName;
  final Value<double?> focal;
  final Value<double?> meteredEv;
  final Value<double?> offsetStops;
  final Value<String?> area;
  final Value<DateTime?> takenAt;
  final Value<int?> utcOffsetMinutes;
  final Value<String?> note;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<double?> locationAccuracy;
  final Value<String?> snapshot;
  final Value<DateTime> updatedAt;
  final Value<String> id;
  final Value<String?> bodyId;
  final Value<String> bodyMake;
  final Value<String> bodyModel;
  final Value<String> format;
  final Value<int> rowid;
  const SavedReadingsCompanion({
    this.mode = const Value.absent(),
    this.aperture = const Value.absent(),
    this.shutter = const Value.absent(),
    this.exposureTime = const Value.absent(),
    this.iso = const Value.absent(),
    this.lensId = const Value.absent(),
    this.lensMake = const Value.absent(),
    this.lensName = const Value.absent(),
    this.focal = const Value.absent(),
    this.meteredEv = const Value.absent(),
    this.offsetStops = const Value.absent(),
    this.area = const Value.absent(),
    this.takenAt = const Value.absent(),
    this.utcOffsetMinutes = const Value.absent(),
    this.note = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.locationAccuracy = const Value.absent(),
    this.snapshot = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.bodyId = const Value.absent(),
    this.bodyMake = const Value.absent(),
    this.bodyModel = const Value.absent(),
    this.format = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedReadingsCompanion.insert({
    this.mode = const Value.absent(),
    this.aperture = const Value.absent(),
    this.shutter = const Value.absent(),
    this.exposureTime = const Value.absent(),
    this.iso = const Value.absent(),
    this.lensId = const Value.absent(),
    this.lensMake = const Value.absent(),
    this.lensName = const Value.absent(),
    this.focal = const Value.absent(),
    this.meteredEv = const Value.absent(),
    this.offsetStops = const Value.absent(),
    this.area = const Value.absent(),
    this.takenAt = const Value.absent(),
    this.utcOffsetMinutes = const Value.absent(),
    this.note = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.locationAccuracy = const Value.absent(),
    this.snapshot = const Value.absent(),
    required DateTime updatedAt,
    required String id,
    this.bodyId = const Value.absent(),
    required String bodyMake,
    required String bodyModel,
    required String format,
    this.rowid = const Value.absent(),
  }) : updatedAt = Value(updatedAt),
       id = Value(id),
       bodyMake = Value(bodyMake),
       bodyModel = Value(bodyModel),
       format = Value(format);
  static Insertable<SavedReadingRow> custom({
    Expression<String>? mode,
    Expression<double>? aperture,
    Expression<String>? shutter,
    Expression<double>? exposureTime,
    Expression<int>? iso,
    Expression<String>? lensId,
    Expression<String>? lensMake,
    Expression<String>? lensName,
    Expression<double>? focal,
    Expression<double>? meteredEv,
    Expression<double>? offsetStops,
    Expression<String>? area,
    Expression<DateTime>? takenAt,
    Expression<int>? utcOffsetMinutes,
    Expression<String>? note,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? locationAccuracy,
    Expression<String>? snapshot,
    Expression<DateTime>? updatedAt,
    Expression<String>? id,
    Expression<String>? bodyId,
    Expression<String>? bodyMake,
    Expression<String>? bodyModel,
    Expression<String>? format,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mode != null) 'mode': mode,
      if (aperture != null) 'aperture': aperture,
      if (shutter != null) 'shutter': shutter,
      if (exposureTime != null) 'exposure_time': exposureTime,
      if (iso != null) 'iso': iso,
      if (lensId != null) 'lens_id': lensId,
      if (lensMake != null) 'lens_make': lensMake,
      if (lensName != null) 'lens_name': lensName,
      if (focal != null) 'focal': focal,
      if (meteredEv != null) 'metered_ev': meteredEv,
      if (offsetStops != null) 'offset_stops': offsetStops,
      if (area != null) 'area': area,
      if (takenAt != null) 'taken_at': takenAt,
      if (utcOffsetMinutes != null) 'utc_offset_minutes': utcOffsetMinutes,
      if (note != null) 'note': note,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (locationAccuracy != null) 'location_accuracy': locationAccuracy,
      if (snapshot != null) 'snapshot': snapshot,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (id != null) 'id': id,
      if (bodyId != null) 'body_id': bodyId,
      if (bodyMake != null) 'body_make': bodyMake,
      if (bodyModel != null) 'body_model': bodyModel,
      if (format != null) 'format': format,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedReadingsCompanion copyWith({
    Value<String?>? mode,
    Value<double?>? aperture,
    Value<String?>? shutter,
    Value<double?>? exposureTime,
    Value<int?>? iso,
    Value<String?>? lensId,
    Value<String?>? lensMake,
    Value<String?>? lensName,
    Value<double?>? focal,
    Value<double?>? meteredEv,
    Value<double?>? offsetStops,
    Value<String?>? area,
    Value<DateTime?>? takenAt,
    Value<int?>? utcOffsetMinutes,
    Value<String?>? note,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<double?>? locationAccuracy,
    Value<String?>? snapshot,
    Value<DateTime>? updatedAt,
    Value<String>? id,
    Value<String?>? bodyId,
    Value<String>? bodyMake,
    Value<String>? bodyModel,
    Value<String>? format,
    Value<int>? rowid,
  }) {
    return SavedReadingsCompanion(
      mode: mode ?? this.mode,
      aperture: aperture ?? this.aperture,
      shutter: shutter ?? this.shutter,
      exposureTime: exposureTime ?? this.exposureTime,
      iso: iso ?? this.iso,
      lensId: lensId ?? this.lensId,
      lensMake: lensMake ?? this.lensMake,
      lensName: lensName ?? this.lensName,
      focal: focal ?? this.focal,
      meteredEv: meteredEv ?? this.meteredEv,
      offsetStops: offsetStops ?? this.offsetStops,
      area: area ?? this.area,
      takenAt: takenAt ?? this.takenAt,
      utcOffsetMinutes: utcOffsetMinutes ?? this.utcOffsetMinutes,
      note: note ?? this.note,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationAccuracy: locationAccuracy ?? this.locationAccuracy,
      snapshot: snapshot ?? this.snapshot,
      updatedAt: updatedAt ?? this.updatedAt,
      id: id ?? this.id,
      bodyId: bodyId ?? this.bodyId,
      bodyMake: bodyMake ?? this.bodyMake,
      bodyModel: bodyModel ?? this.bodyModel,
      format: format ?? this.format,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (aperture.present) {
      map['aperture'] = Variable<double>(aperture.value);
    }
    if (shutter.present) {
      map['shutter'] = Variable<String>(shutter.value);
    }
    if (exposureTime.present) {
      map['exposure_time'] = Variable<double>(exposureTime.value);
    }
    if (iso.present) {
      map['iso'] = Variable<int>(iso.value);
    }
    if (lensId.present) {
      map['lens_id'] = Variable<String>(lensId.value);
    }
    if (lensMake.present) {
      map['lens_make'] = Variable<String>(lensMake.value);
    }
    if (lensName.present) {
      map['lens_name'] = Variable<String>(lensName.value);
    }
    if (focal.present) {
      map['focal'] = Variable<double>(focal.value);
    }
    if (meteredEv.present) {
      map['metered_ev'] = Variable<double>(meteredEv.value);
    }
    if (offsetStops.present) {
      map['offset_stops'] = Variable<double>(offsetStops.value);
    }
    if (area.present) {
      map['area'] = Variable<String>(area.value);
    }
    if (takenAt.present) {
      map['taken_at'] = Variable<DateTime>(takenAt.value);
    }
    if (utcOffsetMinutes.present) {
      map['utc_offset_minutes'] = Variable<int>(utcOffsetMinutes.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (locationAccuracy.present) {
      map['location_accuracy'] = Variable<double>(locationAccuracy.value);
    }
    if (snapshot.present) {
      map['snapshot'] = Variable<String>(snapshot.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bodyId.present) {
      map['body_id'] = Variable<String>(bodyId.value);
    }
    if (bodyMake.present) {
      map['body_make'] = Variable<String>(bodyMake.value);
    }
    if (bodyModel.present) {
      map['body_model'] = Variable<String>(bodyModel.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedReadingsCompanion(')
          ..write('mode: $mode, ')
          ..write('aperture: $aperture, ')
          ..write('shutter: $shutter, ')
          ..write('exposureTime: $exposureTime, ')
          ..write('iso: $iso, ')
          ..write('lensId: $lensId, ')
          ..write('lensMake: $lensMake, ')
          ..write('lensName: $lensName, ')
          ..write('focal: $focal, ')
          ..write('meteredEv: $meteredEv, ')
          ..write('offsetStops: $offsetStops, ')
          ..write('area: $area, ')
          ..write('takenAt: $takenAt, ')
          ..write('utcOffsetMinutes: $utcOffsetMinutes, ')
          ..write('note: $note, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('locationAccuracy: $locationAccuracy, ')
          ..write('snapshot: $snapshot, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('id: $id, ')
          ..write('bodyId: $bodyId, ')
          ..write('bodyMake: $bodyMake, ')
          ..write('bodyModel: $bodyModel, ')
          ..write('format: $format, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$GrainDatabase extends GeneratedDatabase {
  _$GrainDatabase(QueryExecutor e) : super(e);
  $GrainDatabaseManager get managers => $GrainDatabaseManager(this);
  late final $UserProfilesTable userProfiles = $UserProfilesTable(this);
  late final $FavoritesTable favorites = $FavoritesTable(this);
  late final $GearSelectionsTable gearSelections = $GearSelectionsTable(this);
  late final $RollsTable rolls = $RollsTable(this);
  late final $FramesTable frames = $FramesTable(this);
  late final $SavedReadingsTable savedReadings = $SavedReadingsTable(this);
  late final Index framesRollPosition = Index(
    'frames_roll_position',
    'CREATE INDEX frames_roll_position ON frames (roll_id, position)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    userProfiles,
    favorites,
    gearSelections,
    rolls,
    frames,
    savedReadings,
    framesRollPosition,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'rolls',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('frames', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$UserProfilesTableCreateCompanionBuilder =
    UserProfilesCompanion Function({
      required String id,
      required ProfileKind kind,
      required String mount,
      required String json,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$UserProfilesTableUpdateCompanionBuilder =
    UserProfilesCompanion Function({
      Value<String> id,
      Value<ProfileKind> kind,
      Value<String> mount,
      Value<String> json,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$UserProfilesTableFilterComposer
    extends Composer<_$GrainDatabase, $UserProfilesTable> {
  $$UserProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ProfileKind, ProfileKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get mount => $composableBuilder(
    column: $table.mount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserProfilesTableOrderingComposer
    extends Composer<_$GrainDatabase, $UserProfilesTable> {
  $$UserProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mount => $composableBuilder(
    column: $table.mount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProfilesTableAnnotationComposer
    extends Composer<_$GrainDatabase, $UserProfilesTable> {
  $$UserProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ProfileKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get mount =>
      $composableBuilder(column: $table.mount, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserProfilesTableTableManager
    extends
        RootTableManager<
          _$GrainDatabase,
          $UserProfilesTable,
          UserProfile,
          $$UserProfilesTableFilterComposer,
          $$UserProfilesTableOrderingComposer,
          $$UserProfilesTableAnnotationComposer,
          $$UserProfilesTableCreateCompanionBuilder,
          $$UserProfilesTableUpdateCompanionBuilder,
          (
            UserProfile,
            BaseReferences<_$GrainDatabase, $UserProfilesTable, UserProfile>,
          ),
          UserProfile,
          PrefetchHooks Function()
        > {
  $$UserProfilesTableTableManager(_$GrainDatabase db, $UserProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<ProfileKind> kind = const Value.absent(),
                Value<String> mount = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserProfilesCompanion(
                id: id,
                kind: kind,
                mount: mount,
                json: json,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required ProfileKind kind,
                required String mount,
                required String json,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => UserProfilesCompanion.insert(
                id: id,
                kind: kind,
                mount: mount,
                json: json,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UserProfilesTable, UserProfile>(table),
                  BaseReferences<
                    _$GrainDatabase,
                    $UserProfilesTable,
                    UserProfile
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$GrainDatabase,
      $UserProfilesTable,
      UserProfile,
      $$UserProfilesTableFilterComposer,
      $$UserProfilesTableOrderingComposer,
      $$UserProfilesTableAnnotationComposer,
      $$UserProfilesTableCreateCompanionBuilder,
      $$UserProfilesTableUpdateCompanionBuilder,
      (
        UserProfile,
        BaseReferences<_$GrainDatabase, $UserProfilesTable, UserProfile>,
      ),
      UserProfile,
      PrefetchHooks Function()
    >;
typedef $$FavoritesTableCreateCompanionBuilder = FavoritesCompanion Function({
  required ProfileKind kind,
  required String profileId,
  Value<int> rowid,
});
typedef $$FavoritesTableUpdateCompanionBuilder = FavoritesCompanion Function({
  Value<ProfileKind> kind,
  Value<String> profileId,
  Value<int> rowid,
});

class $$FavoritesTableFilterComposer
    extends Composer<_$GrainDatabase, $FavoritesTable> {
  $$FavoritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<ProfileKind, ProfileKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FavoritesTableOrderingComposer
    extends Composer<_$GrainDatabase, $FavoritesTable> {
  $$FavoritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavoritesTableAnnotationComposer
    extends Composer<_$GrainDatabase, $FavoritesTable> {
  $$FavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<ProfileKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);
}

class $$FavoritesTableTableManager
    extends
        RootTableManager<
          _$GrainDatabase,
          $FavoritesTable,
          Favorite,
          $$FavoritesTableFilterComposer,
          $$FavoritesTableOrderingComposer,
          $$FavoritesTableAnnotationComposer,
          $$FavoritesTableCreateCompanionBuilder,
          $$FavoritesTableUpdateCompanionBuilder,
          (
            Favorite,
            BaseReferences<_$GrainDatabase, $FavoritesTable, Favorite>,
          ),
          Favorite,
          PrefetchHooks Function()
        > {
  $$FavoritesTableTableManager(_$GrainDatabase db, $FavoritesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<ProfileKind> kind = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoritesCompanion(
                kind: kind,
                profileId: profileId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required ProfileKind kind,
                required String profileId,
                Value<int> rowid = const Value.absent(),
              }) => FavoritesCompanion.insert(
                kind: kind,
                profileId: profileId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FavoritesTable, Favorite>(table),
                  BaseReferences<_$GrainDatabase, $FavoritesTable, Favorite>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FavoritesTableProcessedTableManager =
    ProcessedTableManager<
      _$GrainDatabase,
      $FavoritesTable,
      Favorite,
      $$FavoritesTableFilterComposer,
      $$FavoritesTableOrderingComposer,
      $$FavoritesTableAnnotationComposer,
      $$FavoritesTableCreateCompanionBuilder,
      $$FavoritesTableUpdateCompanionBuilder,
      (Favorite, BaseReferences<_$GrainDatabase, $FavoritesTable, Favorite>),
      Favorite,
      PrefetchHooks Function()
    >;
typedef $$GearSelectionsTableCreateCompanionBuilder =
    GearSelectionsCompanion Function({
      Value<int> id,
      Value<String?> bodyId,
      Value<String?> lensId,
      Value<double?> focal,
    });
typedef $$GearSelectionsTableUpdateCompanionBuilder =
    GearSelectionsCompanion Function({
      Value<int> id,
      Value<String?> bodyId,
      Value<String?> lensId,
      Value<double?> focal,
    });

class $$GearSelectionsTableFilterComposer
    extends Composer<_$GrainDatabase, $GearSelectionsTable> {
  $$GearSelectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyId => $composableBuilder(
    column: $table.bodyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lensId => $composableBuilder(
    column: $table.lensId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get focal => $composableBuilder(
    column: $table.focal,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GearSelectionsTableOrderingComposer
    extends Composer<_$GrainDatabase, $GearSelectionsTable> {
  $$GearSelectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyId => $composableBuilder(
    column: $table.bodyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lensId => $composableBuilder(
    column: $table.lensId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get focal => $composableBuilder(
    column: $table.focal,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GearSelectionsTableAnnotationComposer
    extends Composer<_$GrainDatabase, $GearSelectionsTable> {
  $$GearSelectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bodyId =>
      $composableBuilder(column: $table.bodyId, builder: (column) => column);

  GeneratedColumn<String> get lensId =>
      $composableBuilder(column: $table.lensId, builder: (column) => column);

  GeneratedColumn<double> get focal =>
      $composableBuilder(column: $table.focal, builder: (column) => column);
}

class $$GearSelectionsTableTableManager
    extends
        RootTableManager<
          _$GrainDatabase,
          $GearSelectionsTable,
          GearSelection,
          $$GearSelectionsTableFilterComposer,
          $$GearSelectionsTableOrderingComposer,
          $$GearSelectionsTableAnnotationComposer,
          $$GearSelectionsTableCreateCompanionBuilder,
          $$GearSelectionsTableUpdateCompanionBuilder,
          (
            GearSelection,
            BaseReferences<
              _$GrainDatabase,
              $GearSelectionsTable,
              GearSelection
            >,
          ),
          GearSelection,
          PrefetchHooks Function()
        > {
  $$GearSelectionsTableTableManager(
    _$GrainDatabase db,
    $GearSelectionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GearSelectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GearSelectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GearSelectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> bodyId = const Value.absent(),
                Value<String?> lensId = const Value.absent(),
                Value<double?> focal = const Value.absent(),
              }) => GearSelectionsCompanion(
                id: id,
                bodyId: bodyId,
                lensId: lensId,
                focal: focal,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> bodyId = const Value.absent(),
                Value<String?> lensId = const Value.absent(),
                Value<double?> focal = const Value.absent(),
              }) => GearSelectionsCompanion.insert(
                id: id,
                bodyId: bodyId,
                lensId: lensId,
                focal: focal,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GearSelectionsTable, GearSelection>(table),
                  BaseReferences<
                    _$GrainDatabase,
                    $GearSelectionsTable,
                    GearSelection
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GearSelectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$GrainDatabase,
      $GearSelectionsTable,
      GearSelection,
      $$GearSelectionsTableFilterComposer,
      $$GearSelectionsTableOrderingComposer,
      $$GearSelectionsTableAnnotationComposer,
      $$GearSelectionsTableCreateCompanionBuilder,
      $$GearSelectionsTableUpdateCompanionBuilder,
      (
        GearSelection,
        BaseReferences<_$GrainDatabase, $GearSelectionsTable, GearSelection>,
      ),
      GearSelection,
      PrefetchHooks Function()
    >;
typedef $$RollsTableCreateCompanionBuilder = RollsCompanion Function({
  required String id,
  required int number,
  required String filmStock,
  required String filmType,
  required int boxIso,
  required int pushThirds,
  Value<String?> bodyId,
  required String bodyMake,
  required String bodyModel,
  required String format,
  required int size,
  required String startFrame,
  Value<String> notes,
  Value<int?> latitudeUnderHalves,
  Value<int?> latitudeOverHalves,
  required String status,
  required DateTime startedAt,
  Value<DateTime?> finishedAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$RollsTableUpdateCompanionBuilder = RollsCompanion Function({
  Value<String> id,
  Value<int> number,
  Value<String> filmStock,
  Value<String> filmType,
  Value<int> boxIso,
  Value<int> pushThirds,
  Value<String?> bodyId,
  Value<String> bodyMake,
  Value<String> bodyModel,
  Value<String> format,
  Value<int> size,
  Value<String> startFrame,
  Value<String> notes,
  Value<int?> latitudeUnderHalves,
  Value<int?> latitudeOverHalves,
  Value<String> status,
  Value<DateTime> startedAt,
  Value<DateTime?> finishedAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$RollsTableReferences
    extends BaseReferences<_$GrainDatabase, $RollsTable, RollRow> {
  $$RollsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FramesTable, List<FrameRow>> _framesRefsTable(
    _$GrainDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.frames,
    aliasName: 'rolls__id__frames__roll_id',
  );

  $$FramesTableProcessedTableManager get framesRefs {
    final manager = $$FramesTableTableManager(
      $_db,
      $_db.frames,
    ).filter((f) => f.rollId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_framesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RollsTableFilterComposer
    extends Composer<_$GrainDatabase, $RollsTable> {
  $$RollsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filmStock => $composableBuilder(
    column: $table.filmStock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filmType => $composableBuilder(
    column: $table.filmType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get boxIso => $composableBuilder(
    column: $table.boxIso,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pushThirds => $composableBuilder(
    column: $table.pushThirds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyId => $composableBuilder(
    column: $table.bodyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyMake => $composableBuilder(
    column: $table.bodyMake,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyModel => $composableBuilder(
    column: $table.bodyModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startFrame => $composableBuilder(
    column: $table.startFrame,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get latitudeUnderHalves => $composableBuilder(
    column: $table.latitudeUnderHalves,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get latitudeOverHalves => $composableBuilder(
    column: $table.latitudeOverHalves,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> framesRefs(
    Expression<bool> Function($$FramesTableFilterComposer f) f,
  ) {
    final $$FramesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.frames,
      getReferencedColumn: (t) => t.rollId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FramesTableFilterComposer(
            $db: $db,
            $table: $db.frames,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RollsTableOrderingComposer
    extends Composer<_$GrainDatabase, $RollsTable> {
  $$RollsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filmStock => $composableBuilder(
    column: $table.filmStock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filmType => $composableBuilder(
    column: $table.filmType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get boxIso => $composableBuilder(
    column: $table.boxIso,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pushThirds => $composableBuilder(
    column: $table.pushThirds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyId => $composableBuilder(
    column: $table.bodyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyMake => $composableBuilder(
    column: $table.bodyMake,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyModel => $composableBuilder(
    column: $table.bodyModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startFrame => $composableBuilder(
    column: $table.startFrame,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get latitudeUnderHalves => $composableBuilder(
    column: $table.latitudeUnderHalves,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get latitudeOverHalves => $composableBuilder(
    column: $table.latitudeOverHalves,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RollsTableAnnotationComposer
    extends Composer<_$GrainDatabase, $RollsTable> {
  $$RollsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<String> get filmStock =>
      $composableBuilder(column: $table.filmStock, builder: (column) => column);

  GeneratedColumn<String> get filmType =>
      $composableBuilder(column: $table.filmType, builder: (column) => column);

  GeneratedColumn<int> get boxIso =>
      $composableBuilder(column: $table.boxIso, builder: (column) => column);

  GeneratedColumn<int> get pushThirds => $composableBuilder(
    column: $table.pushThirds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bodyId =>
      $composableBuilder(column: $table.bodyId, builder: (column) => column);

  GeneratedColumn<String> get bodyMake =>
      $composableBuilder(column: $table.bodyMake, builder: (column) => column);

  GeneratedColumn<String> get bodyModel =>
      $composableBuilder(column: $table.bodyModel, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get startFrame => $composableBuilder(
    column: $table.startFrame,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get latitudeUnderHalves => $composableBuilder(
    column: $table.latitudeUnderHalves,
    builder: (column) => column,
  );

  GeneratedColumn<int> get latitudeOverHalves => $composableBuilder(
    column: $table.latitudeOverHalves,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> framesRefs<T extends Object>(
    Expression<T> Function($$FramesTableAnnotationComposer a) f,
  ) {
    final $$FramesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.frames,
      getReferencedColumn: (t) => t.rollId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FramesTableAnnotationComposer(
            $db: $db,
            $table: $db.frames,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RollsTableTableManager
    extends
        RootTableManager<
          _$GrainDatabase,
          $RollsTable,
          RollRow,
          $$RollsTableFilterComposer,
          $$RollsTableOrderingComposer,
          $$RollsTableAnnotationComposer,
          $$RollsTableCreateCompanionBuilder,
          $$RollsTableUpdateCompanionBuilder,
          (RollRow, $$RollsTableReferences),
          RollRow,
          PrefetchHooks Function({bool framesRefs})
        > {
  $$RollsTableTableManager(_$GrainDatabase db, $RollsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RollsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RollsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RollsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> number = const Value.absent(),
                Value<String> filmStock = const Value.absent(),
                Value<String> filmType = const Value.absent(),
                Value<int> boxIso = const Value.absent(),
                Value<int> pushThirds = const Value.absent(),
                Value<String?> bodyId = const Value.absent(),
                Value<String> bodyMake = const Value.absent(),
                Value<String> bodyModel = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<String> startFrame = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<int?> latitudeUnderHalves = const Value.absent(),
                Value<int?> latitudeOverHalves = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RollsCompanion(
                id: id,
                number: number,
                filmStock: filmStock,
                filmType: filmType,
                boxIso: boxIso,
                pushThirds: pushThirds,
                bodyId: bodyId,
                bodyMake: bodyMake,
                bodyModel: bodyModel,
                format: format,
                size: size,
                startFrame: startFrame,
                notes: notes,
                latitudeUnderHalves: latitudeUnderHalves,
                latitudeOverHalves: latitudeOverHalves,
                status: status,
                startedAt: startedAt,
                finishedAt: finishedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int number,
                required String filmStock,
                required String filmType,
                required int boxIso,
                required int pushThirds,
                Value<String?> bodyId = const Value.absent(),
                required String bodyMake,
                required String bodyModel,
                required String format,
                required int size,
                required String startFrame,
                Value<String> notes = const Value.absent(),
                Value<int?> latitudeUnderHalves = const Value.absent(),
                Value<int?> latitudeOverHalves = const Value.absent(),
                required String status,
                required DateTime startedAt,
                Value<DateTime?> finishedAt = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => RollsCompanion.insert(
                id: id,
                number: number,
                filmStock: filmStock,
                filmType: filmType,
                boxIso: boxIso,
                pushThirds: pushThirds,
                bodyId: bodyId,
                bodyMake: bodyMake,
                bodyModel: bodyModel,
                format: format,
                size: size,
                startFrame: startFrame,
                notes: notes,
                latitudeUnderHalves: latitudeUnderHalves,
                latitudeOverHalves: latitudeOverHalves,
                status: status,
                startedAt: startedAt,
                finishedAt: finishedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RollsTable, RollRow>(table),
                  $$RollsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({framesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (framesRefs) db.frames],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (framesRefs)
                    await $_getPrefetchedDataByColumns<
                      RollRow,
                      $RollsTable,
                      FrameRow,
                      $FramesTable
                    >(
                      currentTable: table,
                      referencedTable: $$RollsTableReferences._framesRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$RollsTableReferences(db, table, p0).framesRefs,
                      currentColumn: 'id',
                      referencedColumn: 'roll_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RollsTableProcessedTableManager =
    ProcessedTableManager<
      _$GrainDatabase,
      $RollsTable,
      RollRow,
      $$RollsTableFilterComposer,
      $$RollsTableOrderingComposer,
      $$RollsTableAnnotationComposer,
      $$RollsTableCreateCompanionBuilder,
      $$RollsTableUpdateCompanionBuilder,
      (RollRow, $$RollsTableReferences),
      RollRow,
      PrefetchHooks Function({bool framesRefs})
    >;
typedef $$FramesTableCreateCompanionBuilder = FramesCompanion Function({
  Value<String?> mode,
  Value<double?> aperture,
  Value<String?> shutter,
  Value<double?> exposureTime,
  Value<int?> iso,
  Value<String?> lensId,
  Value<String?> lensMake,
  Value<String?> lensName,
  Value<double?> focal,
  Value<double?> meteredEv,
  Value<double?> offsetStops,
  Value<String?> area,
  Value<DateTime?> takenAt,
  Value<int?> utcOffsetMinutes,
  Value<String?> note,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<double?> locationAccuracy,
  Value<String?> snapshot,
  required DateTime updatedAt,
  required String id,
  required String rollId,
  required int position,
  required int number,
  Value<int> rowid,
});
typedef $$FramesTableUpdateCompanionBuilder = FramesCompanion Function({
  Value<String?> mode,
  Value<double?> aperture,
  Value<String?> shutter,
  Value<double?> exposureTime,
  Value<int?> iso,
  Value<String?> lensId,
  Value<String?> lensMake,
  Value<String?> lensName,
  Value<double?> focal,
  Value<double?> meteredEv,
  Value<double?> offsetStops,
  Value<String?> area,
  Value<DateTime?> takenAt,
  Value<int?> utcOffsetMinutes,
  Value<String?> note,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<double?> locationAccuracy,
  Value<String?> snapshot,
  Value<DateTime> updatedAt,
  Value<String> id,
  Value<String> rollId,
  Value<int> position,
  Value<int> number,
  Value<int> rowid,
});

final class $$FramesTableReferences
    extends BaseReferences<_$GrainDatabase, $FramesTable, FrameRow> {
  $$FramesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RollsTable _rollIdTable(_$GrainDatabase db) =>
      db.rolls.createAlias('frames__roll_id__rolls__id');

  $$RollsTableProcessedTableManager get rollId {
    final $_column = $_itemColumn<String>('roll_id')!;

    final manager = $$RollsTableTableManager(
      $_db,
      $_db.rolls,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_rollIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FramesTableFilterComposer
    extends Composer<_$GrainDatabase, $FramesTable> {
  $$FramesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get aperture => $composableBuilder(
    column: $table.aperture,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shutter => $composableBuilder(
    column: $table.shutter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get exposureTime => $composableBuilder(
    column: $table.exposureTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get iso => $composableBuilder(
    column: $table.iso,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lensId => $composableBuilder(
    column: $table.lensId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lensMake => $composableBuilder(
    column: $table.lensMake,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lensName => $composableBuilder(
    column: $table.lensName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get focal => $composableBuilder(
    column: $table.focal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get meteredEv => $composableBuilder(
    column: $table.meteredEv,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get offsetStops => $composableBuilder(
    column: $table.offsetStops,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get area => $composableBuilder(
    column: $table.area,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get utcOffsetMinutes => $composableBuilder(
    column: $table.utcOffsetMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get locationAccuracy => $composableBuilder(
    column: $table.locationAccuracy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshot => $composableBuilder(
    column: $table.snapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  $$RollsTableFilterComposer get rollId {
    final $$RollsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rollId,
      referencedTable: $db.rolls,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RollsTableFilterComposer(
            $db: $db,
            $table: $db.rolls,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FramesTableOrderingComposer
    extends Composer<_$GrainDatabase, $FramesTable> {
  $$FramesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get aperture => $composableBuilder(
    column: $table.aperture,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shutter => $composableBuilder(
    column: $table.shutter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get exposureTime => $composableBuilder(
    column: $table.exposureTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get iso => $composableBuilder(
    column: $table.iso,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lensId => $composableBuilder(
    column: $table.lensId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lensMake => $composableBuilder(
    column: $table.lensMake,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lensName => $composableBuilder(
    column: $table.lensName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get focal => $composableBuilder(
    column: $table.focal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get meteredEv => $composableBuilder(
    column: $table.meteredEv,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get offsetStops => $composableBuilder(
    column: $table.offsetStops,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get area => $composableBuilder(
    column: $table.area,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get utcOffsetMinutes => $composableBuilder(
    column: $table.utcOffsetMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get locationAccuracy => $composableBuilder(
    column: $table.locationAccuracy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshot => $composableBuilder(
    column: $table.snapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  $$RollsTableOrderingComposer get rollId {
    final $$RollsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rollId,
      referencedTable: $db.rolls,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RollsTableOrderingComposer(
            $db: $db,
            $table: $db.rolls,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FramesTableAnnotationComposer
    extends Composer<_$GrainDatabase, $FramesTable> {
  $$FramesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<double> get aperture =>
      $composableBuilder(column: $table.aperture, builder: (column) => column);

  GeneratedColumn<String> get shutter =>
      $composableBuilder(column: $table.shutter, builder: (column) => column);

  GeneratedColumn<double> get exposureTime => $composableBuilder(
    column: $table.exposureTime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get iso =>
      $composableBuilder(column: $table.iso, builder: (column) => column);

  GeneratedColumn<String> get lensId =>
      $composableBuilder(column: $table.lensId, builder: (column) => column);

  GeneratedColumn<String> get lensMake =>
      $composableBuilder(column: $table.lensMake, builder: (column) => column);

  GeneratedColumn<String> get lensName =>
      $composableBuilder(column: $table.lensName, builder: (column) => column);

  GeneratedColumn<double> get focal =>
      $composableBuilder(column: $table.focal, builder: (column) => column);

  GeneratedColumn<double> get meteredEv =>
      $composableBuilder(column: $table.meteredEv, builder: (column) => column);

  GeneratedColumn<double> get offsetStops => $composableBuilder(
    column: $table.offsetStops,
    builder: (column) => column,
  );

  GeneratedColumn<String> get area =>
      $composableBuilder(column: $table.area, builder: (column) => column);

  GeneratedColumn<DateTime> get takenAt =>
      $composableBuilder(column: $table.takenAt, builder: (column) => column);

  GeneratedColumn<int> get utcOffsetMinutes => $composableBuilder(
    column: $table.utcOffsetMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get locationAccuracy => $composableBuilder(
    column: $table.locationAccuracy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get snapshot =>
      $composableBuilder(column: $table.snapshot, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  $$RollsTableAnnotationComposer get rollId {
    final $$RollsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rollId,
      referencedTable: $db.rolls,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RollsTableAnnotationComposer(
            $db: $db,
            $table: $db.rolls,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FramesTableTableManager
    extends
        RootTableManager<
          _$GrainDatabase,
          $FramesTable,
          FrameRow,
          $$FramesTableFilterComposer,
          $$FramesTableOrderingComposer,
          $$FramesTableAnnotationComposer,
          $$FramesTableCreateCompanionBuilder,
          $$FramesTableUpdateCompanionBuilder,
          (FrameRow, $$FramesTableReferences),
          FrameRow,
          PrefetchHooks Function({bool rollId})
        > {
  $$FramesTableTableManager(_$GrainDatabase db, $FramesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FramesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FramesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FramesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> mode = const Value.absent(),
                Value<double?> aperture = const Value.absent(),
                Value<String?> shutter = const Value.absent(),
                Value<double?> exposureTime = const Value.absent(),
                Value<int?> iso = const Value.absent(),
                Value<String?> lensId = const Value.absent(),
                Value<String?> lensMake = const Value.absent(),
                Value<String?> lensName = const Value.absent(),
                Value<double?> focal = const Value.absent(),
                Value<double?> meteredEv = const Value.absent(),
                Value<double?> offsetStops = const Value.absent(),
                Value<String?> area = const Value.absent(),
                Value<DateTime?> takenAt = const Value.absent(),
                Value<int?> utcOffsetMinutes = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<double?> locationAccuracy = const Value.absent(),
                Value<String?> snapshot = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> rollId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> number = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FramesCompanion(
                mode: mode,
                aperture: aperture,
                shutter: shutter,
                exposureTime: exposureTime,
                iso: iso,
                lensId: lensId,
                lensMake: lensMake,
                lensName: lensName,
                focal: focal,
                meteredEv: meteredEv,
                offsetStops: offsetStops,
                area: area,
                takenAt: takenAt,
                utcOffsetMinutes: utcOffsetMinutes,
                note: note,
                latitude: latitude,
                longitude: longitude,
                locationAccuracy: locationAccuracy,
                snapshot: snapshot,
                updatedAt: updatedAt,
                id: id,
                rollId: rollId,
                position: position,
                number: number,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> mode = const Value.absent(),
                Value<double?> aperture = const Value.absent(),
                Value<String?> shutter = const Value.absent(),
                Value<double?> exposureTime = const Value.absent(),
                Value<int?> iso = const Value.absent(),
                Value<String?> lensId = const Value.absent(),
                Value<String?> lensMake = const Value.absent(),
                Value<String?> lensName = const Value.absent(),
                Value<double?> focal = const Value.absent(),
                Value<double?> meteredEv = const Value.absent(),
                Value<double?> offsetStops = const Value.absent(),
                Value<String?> area = const Value.absent(),
                Value<DateTime?> takenAt = const Value.absent(),
                Value<int?> utcOffsetMinutes = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<double?> locationAccuracy = const Value.absent(),
                Value<String?> snapshot = const Value.absent(),
                required DateTime updatedAt,
                required String id,
                required String rollId,
                required int position,
                required int number,
                Value<int> rowid = const Value.absent(),
              }) => FramesCompanion.insert(
                mode: mode,
                aperture: aperture,
                shutter: shutter,
                exposureTime: exposureTime,
                iso: iso,
                lensId: lensId,
                lensMake: lensMake,
                lensName: lensName,
                focal: focal,
                meteredEv: meteredEv,
                offsetStops: offsetStops,
                area: area,
                takenAt: takenAt,
                utcOffsetMinutes: utcOffsetMinutes,
                note: note,
                latitude: latitude,
                longitude: longitude,
                locationAccuracy: locationAccuracy,
                snapshot: snapshot,
                updatedAt: updatedAt,
                id: id,
                rollId: rollId,
                position: position,
                number: number,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FramesTable, FrameRow>(table),
                  $$FramesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({rollId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (rollId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.rollId,
                        referencedTable: $$FramesTableReferences._rollIdTable(
                          db,
                        ),
                        referencedColumn: $$FramesTableReferences
                            ._rollIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FramesTableProcessedTableManager =
    ProcessedTableManager<
      _$GrainDatabase,
      $FramesTable,
      FrameRow,
      $$FramesTableFilterComposer,
      $$FramesTableOrderingComposer,
      $$FramesTableAnnotationComposer,
      $$FramesTableCreateCompanionBuilder,
      $$FramesTableUpdateCompanionBuilder,
      (FrameRow, $$FramesTableReferences),
      FrameRow,
      PrefetchHooks Function({bool rollId})
    >;
typedef $$SavedReadingsTableCreateCompanionBuilder =
    SavedReadingsCompanion Function({
      Value<String?> mode,
      Value<double?> aperture,
      Value<String?> shutter,
      Value<double?> exposureTime,
      Value<int?> iso,
      Value<String?> lensId,
      Value<String?> lensMake,
      Value<String?> lensName,
      Value<double?> focal,
      Value<double?> meteredEv,
      Value<double?> offsetStops,
      Value<String?> area,
      Value<DateTime?> takenAt,
      Value<int?> utcOffsetMinutes,
      Value<String?> note,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<double?> locationAccuracy,
      Value<String?> snapshot,
      required DateTime updatedAt,
      required String id,
      Value<String?> bodyId,
      required String bodyMake,
      required String bodyModel,
      required String format,
      Value<int> rowid,
    });
typedef $$SavedReadingsTableUpdateCompanionBuilder =
    SavedReadingsCompanion Function({
      Value<String?> mode,
      Value<double?> aperture,
      Value<String?> shutter,
      Value<double?> exposureTime,
      Value<int?> iso,
      Value<String?> lensId,
      Value<String?> lensMake,
      Value<String?> lensName,
      Value<double?> focal,
      Value<double?> meteredEv,
      Value<double?> offsetStops,
      Value<String?> area,
      Value<DateTime?> takenAt,
      Value<int?> utcOffsetMinutes,
      Value<String?> note,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<double?> locationAccuracy,
      Value<String?> snapshot,
      Value<DateTime> updatedAt,
      Value<String> id,
      Value<String?> bodyId,
      Value<String> bodyMake,
      Value<String> bodyModel,
      Value<String> format,
      Value<int> rowid,
    });

class $$SavedReadingsTableFilterComposer
    extends Composer<_$GrainDatabase, $SavedReadingsTable> {
  $$SavedReadingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get aperture => $composableBuilder(
    column: $table.aperture,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shutter => $composableBuilder(
    column: $table.shutter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get exposureTime => $composableBuilder(
    column: $table.exposureTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get iso => $composableBuilder(
    column: $table.iso,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lensId => $composableBuilder(
    column: $table.lensId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lensMake => $composableBuilder(
    column: $table.lensMake,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lensName => $composableBuilder(
    column: $table.lensName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get focal => $composableBuilder(
    column: $table.focal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get meteredEv => $composableBuilder(
    column: $table.meteredEv,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get offsetStops => $composableBuilder(
    column: $table.offsetStops,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get area => $composableBuilder(
    column: $table.area,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get utcOffsetMinutes => $composableBuilder(
    column: $table.utcOffsetMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get locationAccuracy => $composableBuilder(
    column: $table.locationAccuracy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshot => $composableBuilder(
    column: $table.snapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyId => $composableBuilder(
    column: $table.bodyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyMake => $composableBuilder(
    column: $table.bodyMake,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyModel => $composableBuilder(
    column: $table.bodyModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SavedReadingsTableOrderingComposer
    extends Composer<_$GrainDatabase, $SavedReadingsTable> {
  $$SavedReadingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get aperture => $composableBuilder(
    column: $table.aperture,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shutter => $composableBuilder(
    column: $table.shutter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get exposureTime => $composableBuilder(
    column: $table.exposureTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get iso => $composableBuilder(
    column: $table.iso,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lensId => $composableBuilder(
    column: $table.lensId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lensMake => $composableBuilder(
    column: $table.lensMake,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lensName => $composableBuilder(
    column: $table.lensName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get focal => $composableBuilder(
    column: $table.focal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get meteredEv => $composableBuilder(
    column: $table.meteredEv,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get offsetStops => $composableBuilder(
    column: $table.offsetStops,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get area => $composableBuilder(
    column: $table.area,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get utcOffsetMinutes => $composableBuilder(
    column: $table.utcOffsetMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get locationAccuracy => $composableBuilder(
    column: $table.locationAccuracy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshot => $composableBuilder(
    column: $table.snapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyId => $composableBuilder(
    column: $table.bodyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyMake => $composableBuilder(
    column: $table.bodyMake,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyModel => $composableBuilder(
    column: $table.bodyModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedReadingsTableAnnotationComposer
    extends Composer<_$GrainDatabase, $SavedReadingsTable> {
  $$SavedReadingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<double> get aperture =>
      $composableBuilder(column: $table.aperture, builder: (column) => column);

  GeneratedColumn<String> get shutter =>
      $composableBuilder(column: $table.shutter, builder: (column) => column);

  GeneratedColumn<double> get exposureTime => $composableBuilder(
    column: $table.exposureTime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get iso =>
      $composableBuilder(column: $table.iso, builder: (column) => column);

  GeneratedColumn<String> get lensId =>
      $composableBuilder(column: $table.lensId, builder: (column) => column);

  GeneratedColumn<String> get lensMake =>
      $composableBuilder(column: $table.lensMake, builder: (column) => column);

  GeneratedColumn<String> get lensName =>
      $composableBuilder(column: $table.lensName, builder: (column) => column);

  GeneratedColumn<double> get focal =>
      $composableBuilder(column: $table.focal, builder: (column) => column);

  GeneratedColumn<double> get meteredEv =>
      $composableBuilder(column: $table.meteredEv, builder: (column) => column);

  GeneratedColumn<double> get offsetStops => $composableBuilder(
    column: $table.offsetStops,
    builder: (column) => column,
  );

  GeneratedColumn<String> get area =>
      $composableBuilder(column: $table.area, builder: (column) => column);

  GeneratedColumn<DateTime> get takenAt =>
      $composableBuilder(column: $table.takenAt, builder: (column) => column);

  GeneratedColumn<int> get utcOffsetMinutes => $composableBuilder(
    column: $table.utcOffsetMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get locationAccuracy => $composableBuilder(
    column: $table.locationAccuracy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get snapshot =>
      $composableBuilder(column: $table.snapshot, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bodyId =>
      $composableBuilder(column: $table.bodyId, builder: (column) => column);

  GeneratedColumn<String> get bodyMake =>
      $composableBuilder(column: $table.bodyMake, builder: (column) => column);

  GeneratedColumn<String> get bodyModel =>
      $composableBuilder(column: $table.bodyModel, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);
}

class $$SavedReadingsTableTableManager
    extends
        RootTableManager<
          _$GrainDatabase,
          $SavedReadingsTable,
          SavedReadingRow,
          $$SavedReadingsTableFilterComposer,
          $$SavedReadingsTableOrderingComposer,
          $$SavedReadingsTableAnnotationComposer,
          $$SavedReadingsTableCreateCompanionBuilder,
          $$SavedReadingsTableUpdateCompanionBuilder,
          (
            SavedReadingRow,
            BaseReferences<
              _$GrainDatabase,
              $SavedReadingsTable,
              SavedReadingRow
            >,
          ),
          SavedReadingRow,
          PrefetchHooks Function()
        > {
  $$SavedReadingsTableTableManager(
    _$GrainDatabase db,
    $SavedReadingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedReadingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedReadingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedReadingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> mode = const Value.absent(),
                Value<double?> aperture = const Value.absent(),
                Value<String?> shutter = const Value.absent(),
                Value<double?> exposureTime = const Value.absent(),
                Value<int?> iso = const Value.absent(),
                Value<String?> lensId = const Value.absent(),
                Value<String?> lensMake = const Value.absent(),
                Value<String?> lensName = const Value.absent(),
                Value<double?> focal = const Value.absent(),
                Value<double?> meteredEv = const Value.absent(),
                Value<double?> offsetStops = const Value.absent(),
                Value<String?> area = const Value.absent(),
                Value<DateTime?> takenAt = const Value.absent(),
                Value<int?> utcOffsetMinutes = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<double?> locationAccuracy = const Value.absent(),
                Value<String?> snapshot = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String?> bodyId = const Value.absent(),
                Value<String> bodyMake = const Value.absent(),
                Value<String> bodyModel = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedReadingsCompanion(
                mode: mode,
                aperture: aperture,
                shutter: shutter,
                exposureTime: exposureTime,
                iso: iso,
                lensId: lensId,
                lensMake: lensMake,
                lensName: lensName,
                focal: focal,
                meteredEv: meteredEv,
                offsetStops: offsetStops,
                area: area,
                takenAt: takenAt,
                utcOffsetMinutes: utcOffsetMinutes,
                note: note,
                latitude: latitude,
                longitude: longitude,
                locationAccuracy: locationAccuracy,
                snapshot: snapshot,
                updatedAt: updatedAt,
                id: id,
                bodyId: bodyId,
                bodyMake: bodyMake,
                bodyModel: bodyModel,
                format: format,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> mode = const Value.absent(),
                Value<double?> aperture = const Value.absent(),
                Value<String?> shutter = const Value.absent(),
                Value<double?> exposureTime = const Value.absent(),
                Value<int?> iso = const Value.absent(),
                Value<String?> lensId = const Value.absent(),
                Value<String?> lensMake = const Value.absent(),
                Value<String?> lensName = const Value.absent(),
                Value<double?> focal = const Value.absent(),
                Value<double?> meteredEv = const Value.absent(),
                Value<double?> offsetStops = const Value.absent(),
                Value<String?> area = const Value.absent(),
                Value<DateTime?> takenAt = const Value.absent(),
                Value<int?> utcOffsetMinutes = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<double?> locationAccuracy = const Value.absent(),
                Value<String?> snapshot = const Value.absent(),
                required DateTime updatedAt,
                required String id,
                Value<String?> bodyId = const Value.absent(),
                required String bodyMake,
                required String bodyModel,
                required String format,
                Value<int> rowid = const Value.absent(),
              }) => SavedReadingsCompanion.insert(
                mode: mode,
                aperture: aperture,
                shutter: shutter,
                exposureTime: exposureTime,
                iso: iso,
                lensId: lensId,
                lensMake: lensMake,
                lensName: lensName,
                focal: focal,
                meteredEv: meteredEv,
                offsetStops: offsetStops,
                area: area,
                takenAt: takenAt,
                utcOffsetMinutes: utcOffsetMinutes,
                note: note,
                latitude: latitude,
                longitude: longitude,
                locationAccuracy: locationAccuracy,
                snapshot: snapshot,
                updatedAt: updatedAt,
                id: id,
                bodyId: bodyId,
                bodyMake: bodyMake,
                bodyModel: bodyModel,
                format: format,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SavedReadingsTable, SavedReadingRow>(table),
                  BaseReferences<
                    _$GrainDatabase,
                    $SavedReadingsTable,
                    SavedReadingRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SavedReadingsTableProcessedTableManager =
    ProcessedTableManager<
      _$GrainDatabase,
      $SavedReadingsTable,
      SavedReadingRow,
      $$SavedReadingsTableFilterComposer,
      $$SavedReadingsTableOrderingComposer,
      $$SavedReadingsTableAnnotationComposer,
      $$SavedReadingsTableCreateCompanionBuilder,
      $$SavedReadingsTableUpdateCompanionBuilder,
      (
        SavedReadingRow,
        BaseReferences<_$GrainDatabase, $SavedReadingsTable, SavedReadingRow>,
      ),
      SavedReadingRow,
      PrefetchHooks Function()
    >;

class $GrainDatabaseManager {
  final _$GrainDatabase _db;
  $GrainDatabaseManager(this._db);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db, _db.userProfiles);
  $$FavoritesTableTableManager get favorites =>
      $$FavoritesTableTableManager(_db, _db.favorites);
  $$GearSelectionsTableTableManager get gearSelections =>
      $$GearSelectionsTableTableManager(_db, _db.gearSelections);
  $$RollsTableTableManager get rolls =>
      $$RollsTableTableManager(_db, _db.rolls);
  $$FramesTableTableManager get frames =>
      $$FramesTableTableManager(_db, _db.frames);
  $$SavedReadingsTableTableManager get savedReadings =>
      $$SavedReadingsTableTableManager(_db, _db.savedReadings);
}
