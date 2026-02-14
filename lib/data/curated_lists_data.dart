import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/curated_list.dart';

const List<CuratedList> kCuratedLists = [
  // 1. Les classiques incontournables
  CuratedList(
    id: 1,
    title: 'Les classiques incontournables',
    subtitle: 'Les œuvres qui ont marqué la littérature',
    description:
        'Une sélection des chefs-d\'œuvre littéraires que tout lecteur devrait découvrir au moins une fois.',
    icon: LucideIcons.landmark,
    gradientColors: [Color(0xFFF5E6C8), Color(0xFFD4A853), Color(0xFF8B6914)],
    books: [
      CuratedBookEntry(
        isbn: '9782070360024',
        title: 'L\'Étranger',
        author: 'Albert Camus',
      ),
      CuratedBookEntry(
        isbn: '9782070368228',
        title: 'Le Petit Prince',
        author: 'Antoine de Saint-Exupéry',
      ),
      CuratedBookEntry(
        isbn: '9782070409228',
        title: 'Les Misérables',
        author: 'Victor Hugo',
      ),
      CuratedBookEntry(
        isbn: '9782070413119',
        title: 'Madame Bovary',
        author: 'Gustave Flaubert',
      ),
      CuratedBookEntry(
        isbn: '9782070360420',
        title: 'La Peste',
        author: 'Albert Camus',
      ),
      CuratedBookEntry(
        isbn: '9782070366149',
        title: 'Germinal',
        author: 'Émile Zola',
      ),
      CuratedBookEntry(
        isbn: '9782070411726',
        title: 'Le Rouge et le Noir',
        author: 'Stendhal',
      ),
      CuratedBookEntry(
        isbn: '9782070360871',
        title: 'L\'Écume des jours',
        author: 'Boris Vian',
      ),
      CuratedBookEntry(
        isbn: '9782070364015',
        title: 'Les Fleurs du mal',
        author: 'Charles Baudelaire',
      ),
      CuratedBookEntry(
        isbn: '9782070408504',
        title: 'Le Comte de Monte-Cristo',
        author: 'Alexandre Dumas',
      ),
    ],
  ),

  // 2. SF : les voyages qui changent tout
  CuratedList(
    id: 2,
    title: 'SF : les voyages qui changent tout',
    subtitle: 'Explorez des mondes extraordinaires',
    description:
        'Les romans de science-fiction qui repoussent les frontières de l\'imagination et questionnent notre humanité.',
    icon: LucideIcons.rocket,
    gradientColors: [Color(0xFF1A1A2E), Color(0xFF4A2D8B), Color(0xFF7B68EE)],
    books: [
      CuratedBookEntry(
        isbn: '9782070368228',
        title: 'Dune',
        author: 'Frank Herbert',
      ),
      CuratedBookEntry(
        isbn: '9782070463619',
        title: 'Fahrenheit 451',
        author: 'Ray Bradbury',
      ),
      CuratedBookEntry(
        isbn: '9782072534911',
        title: '1984',
        author: 'George Orwell',
      ),
      CuratedBookEntry(
        isbn: '9782070368167',
        title: 'Le Meilleur des mondes',
        author: 'Aldous Huxley',
      ),
      CuratedBookEntry(
        isbn: '9782290055984',
        title: 'Fondation',
        author: 'Isaac Asimov',
      ),
      CuratedBookEntry(
        isbn: '9782070415731',
        title: 'Solaris',
        author: 'Stanislas Lem',
      ),
      CuratedBookEntry(
        isbn: '9782290349229',
        title: 'Neuromancien',
        author: 'William Gibson',
      ),
      CuratedBookEntry(
        isbn: '9782253004226',
        title: 'La Nuit des temps',
        author: 'René Barjavel',
      ),
    ],
  ),

  // 3. Fierté française
  CuratedList(
    id: 3,
    title: 'Fierté française',
    subtitle: 'Le meilleur de la littérature française',
    description:
        'Les plumes françaises qui ont rayonné à travers le monde et continuent d\'inspirer des générations de lecteurs.',
    icon: LucideIcons.penTool,
    gradientColors: [Color(0xFFE8F0FE), Color(0xFF4A90D9), Color(0xFF1B4D7A)],
    books: [
      CuratedBookEntry(
        isbn: '9782070360024',
        title: 'L\'Étranger',
        author: 'Albert Camus',
      ),
      CuratedBookEntry(
        isbn: '9782070361243',
        title: 'À la recherche du temps perdu',
        author: 'Marcel Proust',
      ),
      CuratedBookEntry(
        isbn: '9782070368228',
        title: 'Le Petit Prince',
        author: 'Antoine de Saint-Exupéry',
      ),
      CuratedBookEntry(
        isbn: '9782253002468',
        title: 'Les Trois Mousquetaires',
        author: 'Alexandre Dumas',
      ),
      CuratedBookEntry(
        isbn: '9782070413119',
        title: 'Madame Bovary',
        author: 'Gustave Flaubert',
      ),
      CuratedBookEntry(
        isbn: '9782070409228',
        title: 'Les Misérables',
        author: 'Victor Hugo',
      ),
      CuratedBookEntry(
        isbn: '9782070366026',
        title: 'Voyage au bout de la nuit',
        author: 'Louis-Ferdinand Céline',
      ),
      CuratedBookEntry(
        isbn: '9782070364329',
        title: 'Bel-Ami',
        author: 'Guy de Maupassant',
      ),
      CuratedBookEntry(
        isbn: '9782070366149',
        title: 'Germinal',
        author: 'Émile Zola',
      ),
      CuratedBookEntry(
        isbn: '9782070360871',
        title: 'L\'Écume des jours',
        author: 'Boris Vian',
      ),
    ],
  ),

  // 4. Frissons garantis
  CuratedList(
    id: 4,
    title: 'Frissons garantis',
    subtitle: 'Thrillers et polars à couper le souffle',
    description:
        'Des intrigues haletantes, des rebondissements inattendus et des nuits blanches garanties.',
    icon: LucideIcons.search,
    gradientColors: [Color(0xFF1A1A1A), Color(0xFF8B1A1A), Color(0xFFDC3545)],
    books: [
      CuratedBookEntry(
        isbn: '9782253176787',
        title: 'La Vérité sur l\'affaire Harry Quebert',
        author: 'Joël Dicker',
      ),
      CuratedBookEntry(
        isbn: '9782266219181',
        title: 'Les Rivières pourpres',
        author: 'Jean-Christophe Grangé',
      ),
      CuratedBookEntry(
        isbn: '9782253237341',
        title: 'La Fille du train',
        author: 'Paula Hawkins',
      ),
      CuratedBookEntry(
        isbn: '9782253151531',
        title: 'Da Vinci Code',
        author: 'Dan Brown',
      ),
      CuratedBookEntry(
        isbn: '9782020386142',
        title: 'Ne le dis à personne',
        author: 'Harlan Coben',
      ),
      CuratedBookEntry(
        isbn: '9782253157687',
        title: 'Millénium 1 : Les hommes qui n\'aimaient pas les femmes',
        author: 'Stieg Larsson',
      ),
      CuratedBookEntry(
        isbn: '9782266233934',
        title: 'Gone Girl',
        author: 'Gillian Flynn',
      ),
      CuratedBookEntry(
        isbn: '9782253083146',
        title: 'Le Silence des agneaux',
        author: 'Thomas Harris',
      ),
      CuratedBookEntry(
        isbn: '9782226320797',
        title: 'Chanson douce',
        author: 'Leïla Slimani',
      ),
      CuratedBookEntry(
        isbn: '9782070408745',
        title: 'Pars vite et reviens tard',
        author: 'Fred Vargas',
      ),
    ],
  ),

  // 5. Développement personnel
  CuratedList(
    id: 5,
    title: 'Développement personnel',
    subtitle: 'Transforme ta vie, un livre à la fois',
    description:
        'Les livres qui changent les perspectives, développent la résilience et inspirent à devenir la meilleure version de soi.',
    icon: LucideIcons.brain,
    gradientColors: [Color(0xFFD8F3DC), Color(0xFF52B788), Color(0xFF2D6A4F)],
    books: [
      CuratedBookEntry(
        isbn: '9782266289160',
        title: 'Atomic Habits',
        author: 'James Clear',
      ),
      CuratedBookEntry(
        isbn: '9782081375635',
        title: 'L\'Art subtil de s\'en foutre',
        author: 'Mark Manson',
      ),
      CuratedBookEntry(
        isbn: '9782290345566',
        title: 'Père riche, père pauvre',
        author: 'Robert Kiyosaki',
      ),
      CuratedBookEntry(
        isbn: '9782253085348',
        title: 'Le Pouvoir du moment présent',
        author: 'Eckhart Tolle',
      ),
      CuratedBookEntry(
        isbn: '9782290200582',
        title: 'Les 7 habitudes de ceux qui réalisent tout ce qu\'ils entreprennent',
        author: 'Stephen R. Covey',
      ),
      CuratedBookEntry(
        isbn: '9782253087816',
        title: 'Pensées pour moi-même',
        author: 'Marc Aurèle',
      ),
      CuratedBookEntry(
        isbn: '9782081404809',
        title: 'Influence et manipulation',
        author: 'Robert Cialdini',
      ),
      CuratedBookEntry(
        isbn: '9782266282536',
        title: 'Ikigai',
        author: 'Héctor García & Francesc Miralles',
      ),
      CuratedBookEntry(
        isbn: '9782253004011',
        title: 'L\'Alchimiste',
        author: 'Paulo Coelho',
      ),
      CuratedBookEntry(
        isbn: '9782253067900',
        title: 'Sapiens',
        author: 'Yuval Noah Harari',
      ),
    ],
  ),

  // 6. Tour du monde littéraire
  CuratedList(
    id: 6,
    title: 'Tour du monde littéraire',
    subtitle: 'Voyage à travers les cultures',
    description:
        'Des romans du monde entier qui ouvrent des fenêtres sur des cultures et des réalités différentes.',
    icon: LucideIcons.globe2,
    gradientColors: [Color(0xFFE0F7FA), Color(0xFF26A69A), Color(0xFF004D40)],
    books: [
      CuratedBookEntry(
        isbn: '9782070360536',
        title: 'Cent ans de solitude',
        author: 'Gabriel García Márquez',
      ),
      CuratedBookEntry(
        isbn: '9782253933090',
        title: 'Le Dieu des petits riens',
        author: 'Arundhati Roy',
      ),
      CuratedBookEntry(
        isbn: '9782253004226',
        title: 'Mémoires d\'une geisha',
        author: 'Arthur Golden',
      ),
      CuratedBookEntry(
        isbn: '9782264052575',
        title: 'Les Cerfs-volants de Kaboul',
        author: 'Khaled Hosseini',
      ),
      CuratedBookEntry(
        isbn: '9782070793723',
        title: 'Le Parfum',
        author: 'Patrick Süskind',
      ),
      CuratedBookEntry(
        isbn: '9782253151128',
        title: 'La Maison aux esprits',
        author: 'Isabel Allende',
      ),
      CuratedBookEntry(
        isbn: '9782070368747',
        title: 'L\'Amant',
        author: 'Marguerite Duras',
      ),
      CuratedBookEntry(
        isbn: '9782070414550',
        title: 'Le Livre de l\'intranquillité',
        author: 'Fernando Pessoa',
      ),
      CuratedBookEntry(
        isbn: '9782253002567',
        title: 'Le Vieil Homme et la mer',
        author: 'Ernest Hemingway',
      ),
      CuratedBookEntry(
        isbn: '9782070360581',
        title: 'L\'Amour aux temps du choléra',
        author: 'Gabriel García Márquez',
      ),
    ],
  ),

  // 7. En moins de 200 pages
  CuratedList(
    id: 7,
    title: 'En moins de 200 pages',
    subtitle: 'Des pépites courtes mais marquantes',
    description:
        'Parfait pour une lecture rapide sans compromis sur la qualité. Des romans courts qui frappent fort.',
    icon: LucideIcons.zap,
    gradientColors: [Color(0xFFF3E5F5), Color(0xFFAB47BC), Color(0xFF6A1B9A)],
    books: [
      CuratedBookEntry(
        isbn: '9782070360024',
        title: 'L\'Étranger',
        author: 'Albert Camus',
      ),
      CuratedBookEntry(
        isbn: '9782070368228',
        title: 'Le Petit Prince',
        author: 'Antoine de Saint-Exupéry',
      ),
      CuratedBookEntry(
        isbn: '9782070364930',
        title: 'La Métamorphose',
        author: 'Franz Kafka',
      ),
      CuratedBookEntry(
        isbn: '9782070402489',
        title: 'Candide',
        author: 'Voltaire',
      ),
      CuratedBookEntry(
        isbn: '9782070369218',
        title: 'Le Vieil Homme et la mer',
        author: 'Ernest Hemingway',
      ),
      CuratedBookEntry(
        isbn: '9782070367825',
        title: 'L\'Appel de la forêt',
        author: 'Jack London',
      ),
      CuratedBookEntry(
        isbn: '9782070364657',
        title: 'La Perle',
        author: 'John Steinbeck',
      ),
      CuratedBookEntry(
        isbn: '9782253004585',
        title: 'Le Prophète',
        author: 'Khalil Gibran',
      ),
      CuratedBookEntry(
        isbn: '9782070360758',
        title: 'La Chute',
        author: 'Albert Camus',
      ),
      CuratedBookEntry(
        isbn: '9782070368747',
        title: 'L\'Amant',
        author: 'Marguerite Duras',
      ),
    ],
  ),

  // 8. Livres à lire un soir de pluie
  CuratedList(
    id: 8,
    title: 'Livres à lire un soir de pluie',
    subtitle: 'Lectures réconfortantes et atmosphériques',
    description:
        'Des romans doux et enveloppants, parfaits pour se blottir sous un plaid quand la pluie tambourine aux carreaux.',
    icon: LucideIcons.cloudRain,
    gradientColors: [Color(0xFFE0E8F0), Color(0xFF7B9CB5), Color(0xFF3D5A73)],
    books: [
      CuratedBookEntry(
        isbn: '9782070440252',
        title: 'La Délicatesse',
        author: 'David Foenkinos',
      ),
      CuratedBookEntry(
        isbn: '9782253114864',
        title: 'L\'Ombre du vent',
        author: 'Carlos Ruiz Zafón',
      ),
      CuratedBookEntry(
        isbn: '9782264053510',
        title:
            'Le Cercle littéraire des amateurs d\'épluchures de patates',
        author: 'Mary Ann Shaffer',
      ),
      CuratedBookEntry(
        isbn: '9782264044730',
        title: 'Kafka sur le rivage',
        author: 'Haruki Murakami',
      ),
      CuratedBookEntry(
        isbn: '9782266273374',
        title: 'La Librairie de l\'île',
        author: 'Gabrielle Zevin',
      ),
      CuratedBookEntry(
        isbn: '9782266285025',
        title: 'Un appartement à Paris',
        author: 'Guillaume Musso',
      ),
      CuratedBookEntry(
        isbn: '9782020239301',
        title: 'Le Vieux qui lisait des romans d\'amour',
        author: 'Luis Sepúlveda',
      ),
      CuratedBookEntry(
        isbn: '9782070439560',
        title: 'Persuasion',
        author: 'Jane Austen',
      ),
      CuratedBookEntry(
        isbn: '9782253155379',
        title: 'La Part de l\'autre',
        author: 'Éric-Emmanuel Schmitt',
      ),
      CuratedBookEntry(
        isbn: '9782290238622',
        title: 'Stoner',
        author: 'John Williams',
      ),
    ],
  ),

  // 9. Les livres qui font pleurer
  CuratedList(
    id: 9,
    title: 'Les livres qui font pleurer',
    subtitle: 'Les plus émouvants',
    description:
        'Des histoires bouleversantes qui touchent en plein cœur. Préparez les mouchoirs.',
    icon: LucideIcons.heartCrack,
    gradientColors: [Color(0xFFF5E6F0), Color(0xFFD4789B), Color(0xFF8B2252)],
    books: [
      CuratedBookEntry(
        isbn: '9782811215576',
        title: 'Avant toi',
        author: 'Jojo Moyes',
      ),
      CuratedBookEntry(
        isbn: '9782253079910',
        title: 'Oscar et la dame rose',
        author: 'Éric-Emmanuel Schmitt',
      ),
      CuratedBookEntry(
        isbn: '9782264052575',
        title: 'Les Cerfs-volants de Kaboul',
        author: 'Khaled Hosseini',
      ),
      CuratedBookEntry(
        isbn: '9782266093088',
        title: 'La Chambre des officiers',
        author: 'Marc Dugain',
      ),
      CuratedBookEntry(
        isbn: '9782290343715',
        title: 'Ensemble, c\'est tout',
        author: 'Anna Gavalda',
      ),
      CuratedBookEntry(
        isbn: '9782070368228',
        title: 'Le Petit Prince',
        author: 'Antoine de Saint-Exupéry',
      ),
      CuratedBookEntry(
        isbn: '9782266283304',
        title: 'Nos étoiles contraires',
        author: 'John Green',
      ),
      CuratedBookEntry(
        isbn: '9782330013073',
        title: 'La Couleur des sentiments',
        author: 'Kathryn Stockett',
      ),
      CuratedBookEntry(
        isbn: '9782253117186',
        title: 'Un secret',
        author: 'Philippe Grimbert',
      ),
      CuratedBookEntry(
        isbn: '9782757828960',
        title: 'Moi d\'abord',
        author: 'Katherine Pancol',
      ),
    ],
  ),

  // 10. Fous rires garantis
  CuratedList(
    id: 10,
    title: 'Fous rires garantis',
    subtitle: 'Humour littéraire',
    description:
        'Des livres hilarants qui donnent le sourire dès la première page. Idéal pour décompresser.',
    icon: LucideIcons.laugh,
    gradientColors: [Color(0xFFFFF9C4), Color(0xFFFFD54F), Color(0xFFF57F17)],
    books: [
      CuratedBookEntry(
        isbn: '9782070437436',
        title: 'Le Guide du voyageur galactique',
        author: 'Douglas Adams',
      ),
      CuratedBookEntry(
        isbn: '9782253124054',
        title: 'Au secours pardon',
        author: 'Frédéric Beigbeder',
      ),
      CuratedBookEntry(
        isbn: '9782012101333',
        title: 'Astérix le Gaulois',
        author: 'Goscinny & Uderzo',
      ),
      CuratedBookEntry(
        isbn: '9782290077252',
        title: 'Le Journal de Bridget Jones',
        author: 'Helen Fielding',
      ),
      CuratedBookEntry(
        isbn: '9782070315734',
        title: '99 francs',
        author: 'Frédéric Beigbeder',
      ),
      CuratedBookEntry(
        isbn: '9782266218528',
        title: 'Le Vieux qui ne voulait pas fêter son anniversaire',
        author: 'Jonas Jonasson',
      ),
      CuratedBookEntry(
        isbn: '9782070364329',
        title: 'Bel-Ami',
        author: 'Guy de Maupassant',
      ),
      CuratedBookEntry(
        isbn: '9782253012740',
        title: 'Les Tribulations d\'un Chinois en Chine',
        author: 'Jules Verne',
      ),
      CuratedBookEntry(
        isbn: '9782253111184',
        title: 'Hygiène de l\'assassin',
        author: 'Amélie Nothomb',
      ),
      CuratedBookEntry(
        isbn: '9782020363761',
        title: 'Le Monde selon Garp',
        author: 'John Irving',
      ),
    ],
  ),

  // 11. Valise d'été
  CuratedList(
    id: 11,
    title: 'Valise d\'été',
    subtitle: 'Lectures légères et addictives',
    description:
        'Des page-turners parfaits pour la plage, le hamac ou le bord de la piscine. Impossible de les lâcher.',
    icon: LucideIcons.palmtree,
    gradientColors: [Color(0xFFFFF3E0), Color(0xFFFF8A65), Color(0xFFD84315)],
    books: [
      CuratedBookEntry(
        isbn: '9782253004011',
        title: 'L\'Alchimiste',
        author: 'Paulo Coelho',
      ),
      CuratedBookEntry(
        isbn: '9782253176787',
        title: 'La Vérité sur l\'affaire Harry Quebert',
        author: 'Joël Dicker',
      ),
      CuratedBookEntry(
        isbn: '9782253073697',
        title: 'Big Little Lies',
        author: 'Liane Moriarty',
      ),
      CuratedBookEntry(
        isbn: '9782266276252',
        title: 'Et après…',
        author: 'Guillaume Musso',
      ),
      CuratedBookEntry(
        isbn: '9782253157687',
        title: 'Millénium 1 : Les hommes qui n\'aimaient pas les femmes',
        author: 'Stieg Larsson',
      ),
      CuratedBookEntry(
        isbn: '9782253126300',
        title: 'Mange, prie, aime',
        author: 'Elizabeth Gilbert',
      ),
      CuratedBookEntry(
        isbn: '9782072965821',
        title: 'L\'Anomalie',
        author: 'Hervé Le Tellier',
      ),
      CuratedBookEntry(
        isbn: '9782266290609',
        title: 'Où es-tu ?',
        author: 'Marc Levy',
      ),
      CuratedBookEntry(
        isbn: '9782264073105',
        title: 'Eleanor Oliphant va très bien',
        author: 'Gail Honeyman',
      ),
      CuratedBookEntry(
        isbn: '9782330037437',
        title: 'Un été sans les hommes',
        author: 'Siri Hustvedt',
      ),
    ],
  ),

  // 12. Ceux qu'on ne peut pas lâcher
  CuratedList(
    id: 12,
    title: 'Ceux qu\'on ne peut pas lâcher',
    subtitle: 'Les page-turners absolus',
    description:
        'Des livres impossibles à poser. Suspense, rebondissements et nuits blanches au programme.',
    icon: LucideIcons.flame,
    gradientColors: [Color(0xFF2D2D2D), Color(0xFFB33A00), Color(0xFFFF5722)],
    books: [
      CuratedBookEntry(
        isbn: '9782266233934',
        title: 'Gone Girl',
        author: 'Gillian Flynn',
      ),
      CuratedBookEntry(
        isbn: '9782253151531',
        title: 'Da Vinci Code',
        author: 'Dan Brown',
      ),
      CuratedBookEntry(
        isbn: '9782743620066',
        title: 'Shutter Island',
        author: 'Dennis Lehane',
      ),
      CuratedBookEntry(
        isbn: '9782253237341',
        title: 'La Fille du train',
        author: 'Paula Hawkins',
      ),
      CuratedBookEntry(
        isbn: '9782070368228',
        title: 'Dune',
        author: 'Frank Herbert',
      ),
      CuratedBookEntry(
        isbn: '9782020386142',
        title: 'Ne le dis à personne',
        author: 'Harlan Coben',
      ),
      CuratedBookEntry(
        isbn: '9782070408504',
        title: 'Le Comte de Monte-Cristo',
        author: 'Alexandre Dumas',
      ),
      CuratedBookEntry(
        isbn: '9782266274500',
        title: 'Divergente',
        author: 'Veronica Roth',
      ),
      CuratedBookEntry(
        isbn: '9782070793723',
        title: 'Le Parfum',
        author: 'Patrick Süskind',
      ),
      CuratedBookEntry(
        isbn: '9782253067986',
        title: 'Rebecca',
        author: 'Daphné du Maurier',
      ),
    ],
  ),

  // 13. Prix Nobel — les lauréats à lire
  CuratedList(
    id: 13,
    title: 'Prix Nobel — les lauréats à lire',
    subtitle: 'Un tour du monde et du siècle',
    description:
        '10 lauréats incontournables du prix Nobel de littérature, chacun d\'une époque et d\'un horizon différents.',
    icon: LucideIcons.award,
    gradientColors: [Color(0xFFFFF8E1), Color(0xFFD4AF37), Color(0xFF8B6914)],
    books: [
      CuratedBookEntry(
        isbn: '9782070360024',
        title: 'L\'Étranger',
        author: 'Albert Camus',
      ),
      CuratedBookEntry(
        isbn: '9782070360536',
        title: 'Cent ans de solitude',
        author: 'Gabriel García Márquez',
      ),
      CuratedBookEntry(
        isbn: '9782253002567',
        title: 'Le Vieil Homme et la Mer',
        author: 'Ernest Hemingway',
      ),
      CuratedBookEntry(
        isbn: '9782264047960',
        title: 'Beloved',
        author: 'Toni Morrison',
      ),
      CuratedBookEntry(
        isbn: '9782253030737',
        title: 'Pays de neige',
        author: 'Yasunari Kawabata',
      ),
      CuratedBookEntry(
        isbn: '9782253067900',
        title: 'La Végétarienne',
        author: 'Han Kang',
      ),
      CuratedBookEntry(
        isbn: '9782253063193',
        title: 'Les Buddenbrook',
        author: 'Thomas Mann',
      ),
      CuratedBookEntry(
        isbn: '9782070336876',
        title: 'La Place',
        author: 'Annie Ernaux',
      ),
      CuratedBookEntry(
        isbn: '9782020403436',
        title: 'L\'Aveuglement',
        author: 'José Saramago',
      ),
      CuratedBookEntry(
        isbn: '9782070373581',
        title: 'Rue des Boutiques Obscures',
        author: 'Patrick Modiano',
      ),
    ],
  ),

  // 14. Vulgarisation scientifique
  CuratedList(
    id: 14,
    title: 'Vulgarisation scientifique',
    subtitle: 'Comprendre le monde',
    description:
        'Un livre par discipline pour explorer la science sans prise de tête. Du Big Bang aux maths en passant par l\'évolution.',
    icon: LucideIcons.atom,
    gradientColors: [Color(0xFFE3F2FD), Color(0xFF42A5F5), Color(0xFF0D47A1)],
    books: [
      CuratedBookEntry(
        isbn: '9782080297136',
        title: 'Une brève histoire du temps',
        author: 'Stephen Hawking',
      ),
      CuratedBookEntry(
        isbn: '9782253091752',
        title: 'Sapiens : Une brève histoire de l\'humanité',
        author: 'Yuval Noah Harari',
      ),
      CuratedBookEntry(
        isbn: '9782290130902',
        title: 'L\'Univers à portée de main',
        author: 'Christophe Galfard',
      ),
      CuratedBookEntry(
        isbn: '9782738112439',
        title: 'Le Gène égoïste',
        author: 'Richard Dawkins',
      ),
      CuratedBookEntry(
        isbn: '9782501006286',
        title: 'Cosmos',
        author: 'Carl Sagan',
      ),
      CuratedBookEntry(
        isbn: '9782290225790',
        title: 'Le Théorème du parapluie',
        author: 'Mickaël Launay',
      ),
      CuratedBookEntry(
        isbn: '9782080244987',
        title: 'La Théorie du chaos',
        author: 'James Gleick',
      ),
      CuratedBookEntry(
        isbn: '9782290141809',
        title: 'Le Grand Roman des maths',
        author: 'Mickaël Launay',
      ),
      CuratedBookEntry(
        isbn: '9782100791729',
        title: 'Pourquoi E=mc² ?',
        author: 'Brian Cox & Jeff Forshaw',
      ),
      CuratedBookEntry(
        isbn: '9782081343016',
        title: 'Et si… ?',
        author: 'Randall Munroe',
      ),
    ],
  ),
];
