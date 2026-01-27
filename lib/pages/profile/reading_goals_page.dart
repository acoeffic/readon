import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';
import '../../models/reading_goal.dart';
import '../../services/goals_service.dart';

class ReadingGoalsPage extends StatefulWidget {
  const ReadingGoalsPage({super.key});

  @override
  State<ReadingGoalsPage> createState() => _ReadingGoalsPageState();
}

class _ReadingGoalsPageState extends State<ReadingGoalsPage> {
  final GoalsService _goalsService = GoalsService();
  bool _isLoading = true;
  bool _isSaving = false;

  // --- Etat Quantite ---
  int? _quantityTarget;
  bool _isCustomQuantity = false;
  final _customController = TextEditingController();

  // --- Etat Regularite ---
  int? _daysPerWeek;
  int? _streakTarget;
  int? _minutesPerDay;

  // --- Etat Qualite ---
  final Set<GoalType> _selectedQualityGoals = {};
  final Map<GoalType, int> _qualityTargets = {
    GoalType.nonfictionBooks: 5,
    GoalType.fictionBooks: 5,
    GoalType.finishStarted: 100,
    GoalType.differentGenres: 5,
  };

  @override
  void initState() {
    super.initState();
    _loadExistingGoals();
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingGoals() async {
    setState(() => _isLoading = true);
    try {
      final goals = await _goalsService.getActiveGoalsWithProgress();
      if (mounted) {
        _initFromExistingGoals(goals);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Erreur _loadExistingGoals: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initFromExistingGoals(List<ReadingGoal> goals) {
    for (final goal in goals) {
      switch (goal.goalType) {
        case GoalType.booksPerYear:
          _quantityTarget = goal.targetValue;
          if (![6, 12, 24, 52].contains(goal.targetValue)) {
            _isCustomQuantity = true;
            _customController.text = goal.targetValue.toString();
          }
          break;
        case GoalType.daysPerWeek:
          _daysPerWeek = goal.targetValue;
          break;
        case GoalType.streakTarget:
          _streakTarget = goal.targetValue;
          break;
        case GoalType.minutesPerDay:
          _minutesPerDay = goal.targetValue;
          break;
        default:
          _selectedQualityGoals.add(goal.goalType);
          _qualityTargets[goal.goalType] = goal.targetValue;
          break;
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final goals = <GoalType, int>{};

    // Quantite
    if (_quantityTarget != null && _quantityTarget! > 0) {
      goals[GoalType.booksPerYear] = _quantityTarget!;
    }

    // Regularite
    if (_daysPerWeek != null) {
      goals[GoalType.daysPerWeek] = _daysPerWeek!;
    }
    if (_streakTarget != null) {
      goals[GoalType.streakTarget] = _streakTarget!;
    }
    if (_minutesPerDay != null) {
      goals[GoalType.minutesPerDay] = _minutesPerDay!;
    }

    // Qualite
    for (final goalType in _selectedQualityGoals) {
      goals[goalType] = _qualityTargets[goalType] ?? 5;
    }

    try {
      await _goalsService.saveAllGoals(goals);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Objectifs enregistres !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpace.l),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const BackHeader(
                            title: 'Mes objectifs',
                            titleColor: AppColors.primary,
                          ),
                          const SizedBox(height: AppSpace.s),

                          // Sous-titre
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s),
                            child: Text(
                              'Personnalise tes objectifs pour rester motive et suivre ta progression.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpace.xl),

                          // ===== SECTION 1 : QUANTITE =====
                          _buildSectionHeader('📊', 'Objectif de quantite'),
                          _buildSectionSubtitle('Combien de livres veux-tu lire cette annee ?'),
                          const SizedBox(height: AppSpace.m),
                          _buildQuantitySection(),

                          _buildDivider(),

                          // ===== SECTION 2 : REGULARITE =====
                          _buildSectionHeader('🔥', 'Objectifs de regularite'),
                          _buildSectionSubtitle('La constance est la cle. Choisis ce qui te motive.'),
                          const SizedBox(height: AppSpace.m),
                          _buildRegularitySection(),

                          _buildDivider(),

                          // ===== SECTION 3 : QUALITE =====
                          _buildSectionHeader('🎯', 'Objectifs de qualite'),
                          _buildSectionSubtitle('Donne une intention a tes lectures.'),
                          const SizedBox(height: AppSpace.m),
                          _buildQualitySection(),

                          const SizedBox(height: AppSpace.xl),
                        ],
                      ),
                    ),
                  ),

                  // ===== BOUTON SAVE =====
                  _buildSaveButton(),
                ],
              ),
      ),
    );
  }

  // ================================================================
  // SECTION HEADERS
  // ================================================================

  Widget _buildSectionHeader(String emoji, String title) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: AppSpace.s),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20),
        ),
      ],
    );
  }

  Widget _buildSectionSubtitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // SECTION QUANTITE
  // ================================================================

  Widget _buildQuantitySection() {
    final presets = [
      _QuantityPreset('📘', '6 livres par an', 'Soft / debutant', '~10 min/jour', 6),
      _QuantityPreset('📗', '1 livre par mois', '12 livres/an', '~20 min/jour', 12),
      _QuantityPreset('📕', '2 livres par mois', '24 livres/an', '~40 min/jour', 24),
      _QuantityPreset('📙', '1 livre par semaine', '52 livres/an', '~1h/jour', 52),
    ];

    return Column(
      children: [
        ...presets.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.m),
              child: _buildQuantityCard(p),
            )),
        _buildCustomQuantityCard(),
      ],
    );
  }

  Widget _buildQuantityCard(_QuantityPreset preset) {
    final isSelected = !_isCustomQuantity && _quantityTarget == preset.books;

    return GestureDetector(
      onTap: () {
        setState(() {
          _quantityTarget = preset.books;
          _isCustomQuantity = false;
          _customController.clear();
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.l),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Theme.of(context).cardColor,
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
          ),
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
        child: Row(
          children: [
            Text(preset.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.label,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preset.sublabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            // Time badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '⏱ ${preset.time}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: AppSpace.s),
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomQuantityCard() {
    final isSelected = _isCustomQuantity && _quantityTarget != null;

    return GestureDetector(
      onTap: () {
        setState(() => _isCustomQuantity = true);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.l),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Theme.of(context).cardColor,
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
          ),
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
        child: Row(
          children: [
            const Text('✨', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Objectif libre',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: AppSpace.s),
                  SizedBox(
                    width: 160,
                    height: 42,
                    child: TextField(
                      controller: _customController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Ex: 18, 30, 40...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.m),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.m),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _isCustomQuantity = true;
                          _quantityTarget = int.tryParse(value);
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // SECTION REGULARITE
  // ================================================================

  Widget _buildRegularitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Jours par semaine
        _buildRegularitySubHeader('🔁', 'Jours de lecture par semaine'),
        const SizedBox(height: AppSpace.m),
        _buildChipRow(
          values: [3, 5, 7],
          labels: ['3 jours', '5 jours', '7 jours'],
          selectedValue: _daysPerWeek,
          onSelected: (v) => setState(() {
            _daysPerWeek = _daysPerWeek == v ? null : v;
          }),
        ),

        const SizedBox(height: AppSpace.l),

        // Streak cible
        _buildRegularitySubHeader('🔥', 'Maintenir un streak de'),
        const SizedBox(height: AppSpace.m),
        _buildChipRow(
          values: [7, 30, 100],
          labels: ['7 jours', '30 jours', '100 jours'],
          selectedValue: _streakTarget,
          onSelected: (v) => setState(() {
            _streakTarget = _streakTarget == v ? null : v;
          }),
        ),

        const SizedBox(height: AppSpace.l),

        // Minutes par jour
        _buildRegularitySubHeader('⏱', 'Minutes de lecture par jour'),
        const SizedBox(height: AppSpace.m),
        _buildChipRow(
          values: [10, 20, 30, 45, 60],
          labels: ['10 min', '20 min', '30 min', '45 min', '1h'],
          selectedValue: _minutesPerDay,
          onSelected: (v) => setState(() {
            _minutesPerDay = _minutesPerDay == v ? null : v;
          }),
        ),

        // Resume si au moins un objectif selectionne
        if (_daysPerWeek != null || _streakTarget != null || _minutesPerDay != null) ...[
          const SizedBox(height: AppSpace.l),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpace.m),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.m),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '💡 Objectifs selectionnes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (_daysPerWeek != null) 'Lire $_daysPerWeek jours/semaine',
                    if (_streakTarget != null) 'Streak de $_streakTarget jours',
                    if (_minutesPerDay != null) '$_minutesPerDay min/jour',
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRegularitySubHeader(String emoji, String title) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: AppSpace.s),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildChipRow({
    required List<int> values,
    required List<String> labels,
    required int? selectedValue,
    required ValueChanged<int> onSelected,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(values.length, (i) {
        final isSelected = selectedValue == values[i];
        return GestureDetector(
          onTap: () => onSelected(values[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Theme.of(context).cardColor,
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
              ),
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
            child: Text(
              labels[i],
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        );
      }),
    );
  }

  // ================================================================
  // SECTION QUALITE
  // ================================================================

  Widget _buildQualitySection() {
    final options = [
      _QualityOption(GoalType.nonfictionBooks, '🧠', 'Livres de non-fiction', true),
      _QualityOption(GoalType.fictionBooks, '📖', 'Romans', true),
      _QualityOption(GoalType.finishStarted, '🎯', 'Finir les livres commences', false),
      _QualityOption(GoalType.differentGenres, '🌍', 'Explorer differents genres', true),
    ];

    return Column(
      children: options.map((option) {
        final isSelected = _selectedQualityGoals.contains(option.goalType);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildQualityCard(option, isSelected),
        );
      }).toList(),
    );
  }

  Widget _buildQualityCard(_QualityOption option, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedQualityGoals.remove(option.goalType);
          } else {
            _selectedQualityGoals.add(option.goalType);
          }
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Theme.of(context).cardColor,
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.4)
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(option.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    option.label,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                // Checkbox
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ],
            ),
            // Stepper pour le nombre (si selectionne et besoin d'un nombre)
            if (isSelected && option.hasTarget) ...[
              const SizedBox(height: AppSpace.m),
              Row(
                children: [
                  const SizedBox(width: 36), // Aligner avec le texte
                  Text(
                    'Objectif :',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: AppSpace.m),
                  _buildStepper(
                    value: _qualityTargets[option.goalType] ?? 5,
                    onChanged: (v) {
                      setState(() => _qualityTargets[option.goalType] = v);
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepper({
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: value > 1 ? () => onChanged(value - 1) : null,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.remove,
                size: 18,
                color: value > 1
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
              ),
            ),
          ),
          Container(
            width: 36,
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          InkWell(
            onTap: () => onChanged(value + 1),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(
                Icons.add,
                size: 18,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // BOUTON SAVE
  // ================================================================

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpace.l, AppSpace.m, AppSpace.l, AppSpace.l),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Enregistrer mes objectifs',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: AppSpace.s),
          Text(
            'Tu pourras modifier tes objectifs a tout moment',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// DATA CLASSES
// ================================================================

class _QuantityPreset {
  final String emoji;
  final String label;
  final String sublabel;
  final String time;
  final int books;

  const _QuantityPreset(this.emoji, this.label, this.sublabel, this.time, this.books);
}

class _QualityOption {
  final GoalType goalType;
  final String emoji;
  final String label;
  final bool hasTarget;

  const _QualityOption(this.goalType, this.emoji, this.label, this.hasTarget);
}
