// CMDTRACE BRUTALIST - Minimal JS

// Theme Toggle (Light default, Dark via toggle)
function toggleTheme() {
    const html = document.documentElement;
    const isDark = html.getAttribute('data-theme') === 'dark';

    if (isDark) {
        html.removeAttribute('data-theme');
        localStorage.setItem('cmdtrace-theme', 'light');
    } else {
        html.setAttribute('data-theme', 'dark');
        localStorage.setItem('cmdtrace-theme', 'dark');
    }
}

const translations = {
    en: {
        // Hero
        'hero.title1': '"WHERE WAS THAT CODE',
        'hero.title2': 'CLAUDE WROTE FOR ME?"',
        'hero.subtitle': "You've had 47 sessions this week. The solution you need is buried somewhere in conversation #23... or was it #31? Stop digging through JSONL files.",
        'hero.tagline': 'STOP SEARCHING. START FINDING.',
        'hero.stat1': 'CLI TOOLS',
        'hero.stat2': 'SESSIONS',
        'hero.stat3': 'LOST',

        // Problem
        'problem.badge': 'Sound familiar?',
        'problem.p1.title': '"I KNOW CLAUDE SOLVED THIS BEFORE..."',
        'problem.p1.desc': "You remember the conversation but can't find it. Was it yesterday? Last week? Which project folder?",
        'problem.p1.files': '127 FILES, 2.3GB OF CONVERSATIONS',
        'problem.p2.title': '"MY SESSIONS ARE EVERYWHERE"',
        'problem.p2.desc': 'Claude Code in one folder, OpenCode in another, Antigravity somewhere else. No unified view.',
        'problem.p3.title': '"WHAT WAS THIS SESSION ABOUT?"',
        'problem.p3.desc': 'Session names like "01JHHK9X2M..." tell you nothing. You open each one hoping it\'s the right one.',
        'problem.summary': 'WASTED SEARCHING FOR PAST AI CONVERSATIONS = 2+ HOURS/WEEK LOST',

        // Solution
        'solution.subtitle': 'Native macOS app for AI session management',
        'solution.title': 'CMDTRACE BRINGS ORDER TO CHAOS',
        'solution.b1.title': 'FIND IN SECONDS',
        'solution.b1.desc': 'Search by content, title, tag, or project. No more opening files one by one.',
        'solution.b2.title': 'YOUR ORGANIZATION',
        'solution.b2.desc': 'Custom names, tags, favorites, and pins. Make sense of your sessions.',
        'solution.b3.title': 'INSTANT RESUME',
        'solution.b3.desc': 'Jump back into any session with one click. Terminal, iTerm2, or Warp.',
        'solution.b4.title': 'USAGE INSIGHTS',
        'solution.b4.desc': 'Track your AI usage, costs, and burn rate. Stay within plan limits.',

        // Features
        'features.badge': 'Built for the way you work',
        'features.f1.title': 'FIND ANYTHING, INSTANTLY',
        'features.f1.desc': 'Powerful search operators let you pinpoint exactly what you need.',
        'features.f1.ex1': 'Search inside conversations',
        'features.f1.ex2': 'Filter by tag and project',
        'features.f1.ex3': "Find today's sessions",
        'features.f2.title': 'ALL YOUR AI TOOLS, ONE PLACE',
        'features.f2.desc': 'Switch between Claude Code, OpenCode, and Antigravity instantly.',
        'features.f3.title': 'KNOW YOUR USAGE, STAY IN CONTROL',
        'features.f3.desc': 'Real-time monitoring with burn rate predictions.',
        'features.f3.l1': '[✓] Token usage by model (Opus, Sonnet, Haiku)',
        'features.f3.l2': '[✓] Cost tracking with burn rate projection',
        'features.f3.l3': '[✓] Plan limits for Pro, Max5, Max20',
        'features.f3.l4': '[✓] Integrates with ccusage & claude-monitor',
        'features.f4.title': 'AI-GENERATED SUMMARIES',
        'features.f4.desc': 'Let AI analyze your sessions and generate meaningful titles.',
        'features.f4.l1': '[✓] Auto-generate session titles from content',
        'features.f4.l2': '[✓] Smart summaries for quick context',
        'features.f4.l3': '[✓] Multiple AI providers supported',

        // Workflow
        'workflow.badge': 'Get started in 3 steps',
        'workflow.s1.title': 'DOWNLOAD & LAUNCH',
        'workflow.s1.desc': 'Install CmdTrace. It automatically finds your AI session folders.',
        'workflow.s2.title': 'ORGANIZE YOUR WAY',
        'workflow.s2.desc': 'Add names, tags, and favorites. AI can auto-generate titles.',
        'workflow.s3.title': 'FIND & RESUME',
        'workflow.s3.desc': 'Search, browse, and jump back into any session instantly.',

        // Download
        'download.title': 'STOP LOSING CONVERSATIONS. START FINDING THEM.',
        'download.subtitle': 'CmdTrace is free and open source. Your data stays on your machine.',
        'download.requires': 'MACOS 14+ • NATIVE SWIFTUI • FREE & OPEN SOURCE',
        'download.btn.arm': 'APPLE SILICON',
        'download.btn.intel': 'INTEL MAC',
        'download.gatekeeper.title': '"APP IS DAMAGED" WARNING?',
        'download.gatekeeper.desc': 'This is macOS Gatekeeper security. Run this in Terminal:',
        'download.permissions.title': 'RESUME NOT WORKING?',
        'download.permissions.desc': 'Grant permissions: System Settings → Privacy → Automation → CmdTrace',
        'download.build': 'BUILD FROM SOURCE:',

        // Footer
        'footer.tagline': 'AI SESSION VIEWER FOR MACOS',
        'footer.made': 'MADE WITH',
        'footer.swiftui': 'IN SWIFTUI'
    },
    ko: {
        // Hero
        'hero.title1': '"그때 CLAUDE가 짜준 코드',
        'hero.title2': '어디 갔지?"',
        'hero.subtitle': '이번 주에만 47개 세션. 필요한 솔루션이 23번 대화에 있었나... 아니면 31번이었나? JSONL 파일 뒤지는 건 이제 그만.',
        'hero.tagline': '검색은 그만. 바로 찾으세요.',
        'hero.stat1': 'CLI 도구',
        'hero.stat2': '세션',
        'hero.stat3': '유실',

        // Problem
        'problem.badge': '익숙한 상황인가요?',
        'problem.p1.title': '"CLAUDE가 전에 이거 해결해줬는데..."',
        'problem.p1.desc': '대화 내용은 기억나는데 못 찾겠어요. 어제였나? 지난주? 어느 프로젝트 폴더?',
        'problem.p1.files': '127개 파일, 2.3GB의 대화 기록',
        'problem.p2.title': '"세션이 여기저기 흩어져 있어요"',
        'problem.p2.desc': 'Claude Code는 이 폴더, OpenCode는 저 폴더, Antigravity는 또 다른 곳. 통합 뷰가 없어요.',
        'problem.p3.title': '"이 세션이 뭐에 관한 거지?"',
        'problem.p3.desc': '"01JHHK9X2M..." 같은 세션 이름은 아무 정보도 주지 않아요. 하나씩 열어보며 찾는 수밖에.',
        'problem.summary': '과거 AI 대화 찾는 데 낭비되는 시간 = 주당 2시간 이상',

        // Solution
        'solution.subtitle': 'AI 세션 관리를 위한 네이티브 macOS 앱',
        'solution.title': 'CMDTRACE가 혼란을 정리합니다',
        'solution.b1.title': '즉시 검색',
        'solution.b1.desc': '내용, 제목, 태그, 프로젝트로 검색. 파일을 하나씩 열어볼 필요 없어요.',
        'solution.b2.title': '나만의 정리',
        'solution.b2.desc': '이름, 태그, 즐겨찾기, 고정. 세션을 체계적으로 관리하세요.',
        'solution.b3.title': '즉시 재개',
        'solution.b3.desc': '클릭 한 번으로 세션 재개. Terminal, iTerm2, Warp 지원.',
        'solution.b4.title': '사용량 파악',
        'solution.b4.desc': 'AI 사용량, 비용, 소진율 추적. 플랜 한도 내에서 관리하세요.',

        // Features
        'features.badge': '당신의 워크플로우에 맞게',
        'features.f1.title': '원하는 것을 즉시 검색',
        'features.f1.desc': '강력한 검색 연산자로 필요한 것을 정확히 찾으세요.',
        'features.f1.ex1': '대화 내용 검색',
        'features.f1.ex2': '태그와 프로젝트로 필터링',
        'features.f1.ex3': '오늘 세션 찾기',
        'features.f2.title': '모든 AI 도구를 한 곳에서',
        'features.f2.desc': 'Claude Code, OpenCode, Antigravity 간 즉시 전환.',
        'features.f3.title': '사용량 파악, 통제력 확보',
        'features.f3.desc': '소진율 예측이 포함된 실시간 모니터링.',
        'features.f3.l1': '[✓] 모델별 토큰 사용량 (Opus, Sonnet, Haiku)',
        'features.f3.l2': '[✓] 소진율 예측이 포함된 비용 추적',
        'features.f3.l3': '[✓] 플랜별 한도 (Pro, Max5, Max20)',
        'features.f3.l4': '[✓] ccusage & claude-monitor 연동',
        'features.f4.title': 'AI가 만드는 요약',
        'features.f4.desc': 'AI가 세션을 분석하고 의미 있는 제목을 생성합니다.',
        'features.f4.l1': '[✓] 내용 기반 세션 제목 자동 생성',
        'features.f4.l2': '[✓] 빠른 맥락 파악을 위한 스마트 요약',
        'features.f4.l3': '[✓] 다양한 AI 제공자 지원',

        // Workflow
        'workflow.badge': '3단계로 시작하기',
        'workflow.s1.title': '다운로드 & 실행',
        'workflow.s1.desc': 'CmdTrace 설치. AI 세션 폴더를 자동으로 찾습니다.',
        'workflow.s2.title': '나만의 방식으로 정리',
        'workflow.s2.desc': '이름, 태그, 즐겨찾기 추가. AI가 제목을 자동 생성합니다.',
        'workflow.s3.title': '검색 & 재개',
        'workflow.s3.desc': '검색하고, 둘러보고, 어떤 세션이든 즉시 재개하세요.',

        // Download
        'download.title': '대화를 잃지 마세요. 바로 찾으세요.',
        'download.subtitle': 'CmdTrace는 무료 오픈소스입니다. 데이터는 당신의 기기에만 저장됩니다.',
        'download.requires': 'MACOS 14+ • 네이티브 SWIFTUI • 무료 & 오픈소스',
        'download.btn.arm': 'APPLE SILICON',
        'download.btn.intel': 'INTEL MAC',
        'download.gatekeeper.title': '"앱이 손상되었습니다" 경고?',
        'download.gatekeeper.desc': 'macOS Gatekeeper 보안 기능입니다. 터미널에서 실행하세요:',
        'download.permissions.title': '재개 기능이 안 되나요?',
        'download.permissions.desc': '권한 부여: 시스템 설정 → 개인 정보 보호 → 자동화 → CmdTrace',
        'download.build': '소스에서 빌드:',

        // Footer
        'footer.tagline': 'MACOS용 AI 세션 뷰어',
        'footer.made': '',
        'footer.swiftui': 'SWIFTUI로 제작'
    }
};

let currentLang = 'en';

function toggleLang() {
    currentLang = currentLang === 'en' ? 'ko' : 'en';
    applyTranslations();
    localStorage.setItem('cmdtrace-lang', currentLang);
}

function applyTranslations() {
    const t = translations[currentLang];
    document.querySelectorAll('[data-i18n]').forEach(el => {
        const key = el.getAttribute('data-i18n');
        if (t[key] !== undefined) {
            el.textContent = t[key];
        }
    });
}

// Init
document.addEventListener('DOMContentLoaded', () => {
    // Apply saved language
    const savedLang = localStorage.getItem('cmdtrace-lang');
    if (savedLang && translations[savedLang]) {
        currentLang = savedLang;
        applyTranslations();
    }

    // Apply saved theme (light is default)
    const savedTheme = localStorage.getItem('cmdtrace-theme');
    if (savedTheme === 'dark') {
        document.documentElement.setAttribute('data-theme', 'dark');
    }
});
