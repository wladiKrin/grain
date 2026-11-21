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

abstract class _$GrainDatabase extends GeneratedDatabase {
  _$GrainDatabase(QueryExecutor e) : super(e);
  $GrainDatabaseManager get managers => $GrainDatabaseManager(this);
  late final $UserProfilesTable userProfiles = $UserProfilesTable(this);
  late final $FavoritesTable favorites = $FavoritesTable(this);
  late final $GearSelectionsTable gearSelections = $GearSelectionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    userProfiles,
    favorites,
    gearSelections,
  ];
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

class $GrainDatabaseManager {
  final _$GrainDatabase _db;
  $GrainDatabaseManager(this._db);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db, _db.userProfiles);
  $$FavoritesTableTableManager get favorites =>
      $$FavoritesTableTableManager(_db, _db.favorites);
  $$GearSelectionsTableTableManager get gearSelections =>
      $$GearSelectionsTableTableManager(_db, _db.gearSelections);
}
