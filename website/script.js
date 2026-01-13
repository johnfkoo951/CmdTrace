// ============================================
// CmdTrace Landing Page - Redesigned
// Problem → Solution Storytelling
// ============================================

const translations = {
    en: {
        // Navigation
        'nav.problem': 'The Problem',
        'nav.solution': 'Solution',
        'nav.features': 'Features',
        'nav.download': 'Download',
        'nav.getApp': 'Get the App',

        // Hero
        'hero.badge': 'For AI-Powered Developers',
        'hero.title1': '"Where was that code',
        'hero.title2': 'Claude wrote for me?"',
        'hero.subtitle': "You've had 47 sessions this week. The solution you need is buried somewhere in conversation #23... or was it #31? Stop digging through JSONL files. Start finding what you need.",
        'hero.cta1': 'Download Free',
        'hero.cta2': 'See the Problem',
        'hero.stat1': 'CLI Tools Supported',
        'hero.stat2': 'Sessions Managed',
        'hero.stat3': 'Lost Conversations',

        // Problem Section
        'problem.badge': 'The Problem',
        'problem.title': 'Sound familiar?',
        'problem.p1.title': '"I know Claude solved this before..."',
        'problem.p1.desc': "You remember the conversation but can't find it. Was it yesterday? Last week? Which project folder?",
        'problem.p1.files': '127 files, 2.3GB of conversations',
        'problem.p2.title': '"My sessions are everywhere"',
        'problem.p2.desc': 'Claude Code in one folder, OpenCode in another, Antigravity somewhere else. No unified view, no organization.',
        'problem.p3.title': '"What was this session about?"',
        'problem.p3.desc': 'Session names like "01JHHK9X2M..." tell you nothing. You open each one hoping it\'s the right one.',
        'problem.summary': 'Every day, developers lose <strong>15-30 minutes</strong> searching for past AI conversations. That\'s <strong>2+ hours per week</strong> of productivity lost.',

        // Solution Section
        'solution.badge': 'The Solution',
        'solution.title': 'CmdTrace brings order to chaos',
        'solution.subtitle': 'A native macOS app that understands how you work with AI coding assistants.',
        'solution.b1.title': 'Find in Seconds',
        'solution.b1.desc': 'Search by content, title, tag, or project. No more opening files one by one.',
        'solution.b2.title': 'Your Organization',
        'solution.b2.desc': 'Custom names, tags, favorites, and pins. Make sense of your sessions.',
        'solution.b3.title': 'Instant Resume',
        'solution.b3.desc': 'Jump back into any session with one click. Terminal, iTerm2, or Warp.',
        'solution.b4.title': 'Usage Insights',
        'solution.b4.desc': 'Track your AI usage, costs, and burn rate. Stay within plan limits.',

        // Features Section
        'features.badge': 'Features',
        'features.title': 'Built for the way you work',
        'features.f1.tag': 'SEARCH',
        'features.f1.title': 'Find anything, instantly',
        'features.f1.desc': 'Powerful search operators let you pinpoint exactly what you need. Combine them for laser-precise results.',
        'features.f1.ex1': 'Search inside conversations',
        'features.f1.ex2': 'Filter by tag and project',
        'features.f1.ex3': "Find today's refactoring sessions",
        'features.f2.tag': 'MULTI-CLI',
        'features.f2.title': 'All your AI tools, one place',
        'features.f2.desc': 'Switch between Claude Code, OpenCode, and Antigravity instantly. Sessions are pre-cached for zero wait time.',
        'features.f2.switch': 'Switch CLI',
        'features.f3.tag': 'MONITORING',
        'features.f3.title': 'Know your usage, stay in control',
        'features.f3.desc': 'Real-time monitoring with burn rate predictions. Never hit your plan limit unexpectedly again.',
        'features.f3.l1': 'Token usage by model (Opus, Sonnet, Haiku)',
        'features.f3.l2': 'Cost tracking with burn rate projection',
        'features.f3.l3': 'Plan limits for Pro, Max5, Max20',
        'features.f3.l4': 'Integrates with ccusage & claude-monitor',
        'features.f3.usage': "Today's Usage",
        'features.f4.tag': 'AI POWERED',
        'features.f4.title': 'AI-generated summaries',
        'features.f4.desc': 'Let AI analyze your sessions and generate meaningful titles and summaries. Never struggle with cryptic session names again.',
        'features.f4.l1': 'Auto-generate session titles from content',
        'features.f4.l2': 'Smart summaries for quick context',
        'features.f4.l3': 'Multiple AI providers supported',

        // Workflow Section
        'workflow.badge': 'How It Works',
        'workflow.title': 'Get started in 3 steps',
        'workflow.s1.title': 'Download & Launch',
        'workflow.s1.desc': 'Install CmdTrace. It automatically finds your AI session folders.',
        'workflow.s2.title': 'Organize Your Way',
        'workflow.s2.desc': 'Add names, tags, and favorites. AI can auto-generate titles.',
        'workflow.s3.title': 'Find & Resume',
        'workflow.s3.desc': 'Search, browse, and jump back into any session instantly.',

        // Download Section
        'download.title': 'Stop losing conversations.<br>Start finding them.',
        'download.subtitle': 'CmdTrace is free and open source. Your data stays on your machine.',
        'download.requires': 'macOS 14+',
        'download.native': 'Native SwiftUI',
        'download.btn': 'Download for macOS',
        'download.coming': 'Release coming soon. Star the repo to get notified.',
        'download.build': 'Build from source:',

        // Footer
        'footer.tagline': 'AI Session Viewer for macOS',
        'footer.made': 'Made with',
        'footer.swiftui': 'in SwiftUI'
    },
    ko: {
        // Navigation
        'nav.problem': '문제점',
        'nav.solution': '해결책',
        'nav.features': '기능',
        'nav.download': '다운로드',
        'nav.getApp': '앱 받기',

        // Hero
        'hero.badge': 'AI 개발자를 위한 도구',
        'hero.title1': '"Claude가 짜준 그 코드',
        'hero.title2': '어디 있더라?"',
        'hero.subtitle': '이번 주에만 47개의 세션. 필요한 코드가 23번 대화에 있었던 것 같은데... 아니면 31번이었나? JSONL 파일을 뒤지는 건 그만. 이제 바로 찾으세요.',
        'hero.cta1': '무료 다운로드',
        'hero.cta2': '문제점 보기',
        'hero.stat1': '지원 CLI 도구',
        'hero.stat2': '관리 가능한 세션',
        'hero.stat3': '잃어버린 대화',

        // Problem Section
        'problem.badge': '문제점',
        'problem.title': '이런 경험 있으시죠?',
        'problem.p1.title': '"Claude가 이거 전에 해결해줬는데..."',
        'problem.p1.desc': '대화 내용은 기억나는데 못 찾겠어요. 어제였나? 지난주? 어느 프로젝트 폴더?',
        'problem.p1.files': '127개 파일, 2.3GB의 대화들',
        'problem.p2.title': '"세션이 여기저기 흩어져 있어요"',
        'problem.p2.desc': 'Claude Code는 이 폴더, OpenCode는 저 폴더, Antigravity는 또 다른 곳. 통합 뷰도 없고, 정리도 안 돼요.',
        'problem.p3.title': '"이 세션이 뭐에 관한 거였지?"',
        'problem.p3.desc': '"01JHHK9X2M..." 같은 세션 이름은 아무 정보도 안 줘요. 하나씩 열어보면서 맞는 걸 찾아야 해요.',
        'problem.summary': '개발자들은 매일 <strong>15-30분</strong>을 과거 AI 대화 찾는 데 허비합니다. 일주일이면 <strong>2시간 이상</strong>의 생산성 손실이죠.',

        // Solution Section
        'solution.badge': '해결책',
        'solution.title': 'CmdTrace가 혼란을 정리합니다',
        'solution.subtitle': 'AI 코딩 어시스턴트와 함께 일하는 방식을 이해하는 네이티브 macOS 앱.',
        'solution.b1.title': '몇 초 만에 검색',
        'solution.b1.desc': '내용, 제목, 태그, 프로젝트로 검색. 파일 하나씩 여는 건 그만.',
        'solution.b2.title': '나만의 정리법',
        'solution.b2.desc': '커스텀 이름, 태그, 즐겨찾기, 고정. 세션을 체계적으로.',
        'solution.b3.title': '즉시 재개',
        'solution.b3.desc': '클릭 한 번으로 세션 재개. Terminal, iTerm2, Warp 지원.',
        'solution.b4.title': '사용량 분석',
        'solution.b4.desc': 'AI 사용량, 비용, 소진율 추적. 플랜 한도 내에서 관리.',

        // Features Section
        'features.badge': '기능',
        'features.title': '당신의 워크플로우에 맞게',
        'features.f1.tag': '검색',
        'features.f1.title': '뭐든, 바로 찾기',
        'features.f1.desc': '강력한 검색 연산자로 정확히 원하는 걸 찾으세요. 조합하면 더 정밀하게.',
        'features.f1.ex1': '대화 내용에서 검색',
        'features.f1.ex2': '태그와 프로젝트로 필터',
        'features.f1.ex3': '오늘의 리팩토링 세션 찾기',
        'features.f2.tag': '멀티 CLI',
        'features.f2.title': '모든 AI 도구를, 한 곳에서',
        'features.f2.desc': 'Claude Code, OpenCode, Antigravity 간 즉시 전환. 세션은 프리캐싱되어 대기 시간 제로.',
        'features.f2.switch': 'CLI 전환',
        'features.f3.tag': '모니터링',
        'features.f3.title': '사용량을 파악하고, 통제하세요',
        'features.f3.desc': '소진율 예측과 함께 실시간 모니터링. 플랜 한도에 갑자기 도달하는 일은 없어요.',
        'features.f3.l1': '모델별 토큰 사용량 (Opus, Sonnet, Haiku)',
        'features.f3.l2': '소진율 예측과 함께 비용 추적',
        'features.f3.l3': 'Pro, Max5, Max20 플랜 한도',
        'features.f3.l4': 'ccusage & claude-monitor 연동',
        'features.f3.usage': '오늘의 사용량',
        'features.f4.tag': 'AI 기능',
        'features.f4.title': 'AI가 만드는 요약',
        'features.f4.desc': 'AI가 세션을 분석해 의미 있는 제목과 요약을 생성합니다. 더 이상 알 수 없는 세션 이름으로 고민할 필요 없어요.',
        'features.f4.l1': '내용 기반 세션 제목 자동 생성',
        'features.f4.l2': '빠른 파악을 위한 스마트 요약',
        'features.f4.l3': '다양한 AI 제공자 지원',

        // Workflow Section
        'workflow.badge': '사용 방법',
        'workflow.title': '3단계로 시작하기',
        'workflow.s1.title': '다운로드 & 실행',
        'workflow.s1.desc': 'CmdTrace를 설치하면 AI 세션 폴더를 자동으로 찾습니다.',
        'workflow.s2.title': '나만의 방식으로 정리',
        'workflow.s2.desc': '이름, 태그, 즐겨찾기를 추가하세요. AI가 제목을 자동 생성할 수도 있어요.',
        'workflow.s3.title': '검색 & 재개',
        'workflow.s3.desc': '검색하고, 둘러보고, 어떤 세션이든 바로 다시 시작하세요.',

        // Download Section
        'download.title': '대화를 잃지 마세요.<br>바로 찾으세요.',
        'download.subtitle': 'CmdTrace는 무료이며 오픈소스입니다. 데이터는 당신의 컴퓨터에만 저장됩니다.',
        'download.requires': 'macOS 14+',
        'download.native': '네이티브 SwiftUI',
        'download.btn': 'macOS용 다운로드',
        'download.coming': '곧 출시됩니다. 알림 받으려면 레포에 스타를 눌러주세요.',
        'download.build': '소스에서 빌드:',

        // Footer
        'footer.tagline': 'macOS용 AI 세션 뷰어',
        'footer.made': '만든 이:',
        'footer.swiftui': 'SwiftUI'
    }
};

let currentLang = 'en';

document.addEventListener('DOMContentLoaded', () => {
    // Check saved language
    const savedLang = localStorage.getItem('cmdtrace-lang');
    if (savedLang && translations[savedLang]) {
        currentLang = savedLang;
        applyTranslations(currentLang);
        updateLangIndicator();
    }

    // Smooth scroll
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function(e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        });
    });

    // Intersection Observer for animations
    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach((entry, index) => {
            if (entry.isIntersecting) {
                // Add staggered delay
                setTimeout(() => {
                    entry.target.classList.add('animate-in');
                }, index * 100);
            }
        });
    }, observerOptions);

    // Observe elements
    document.querySelectorAll('.pain-card, .benefit-card, .feature-deep, .workflow-step').forEach(el => {
        observer.observe(el);
    });

    // Navbar scroll effect
    const navbar = document.querySelector('.navbar');
    let lastScroll = 0;

    window.addEventListener('scroll', () => {
        const currentScroll = window.pageYOffset;

        if (currentScroll > 100) {
            navbar.style.background = 'rgba(9, 9, 11, 0.95)';
            navbar.style.boxShadow = '0 4px 20px rgba(0, 0, 0, 0.3)';
        } else {
            navbar.style.background = 'rgba(9, 9, 11, 0.85)';
            navbar.style.boxShadow = 'none';
        }

        lastScroll = currentScroll;
    });

    // Typing animation for search demo
    const typingText = document.querySelector('.typing-text');
    if (typingText) {
        const text = typingText.textContent;
        typingText.textContent = '';
        let i = 0;

        function type() {
            if (i < text.length) {
                typingText.textContent += text.charAt(i);
                i++;
                setTimeout(type, 100);
            }
        }

        // Start typing when visible
        const searchDemo = document.querySelector('.search-demo');
        if (searchDemo) {
            const typingObserver = new IntersectionObserver((entries) => {
                if (entries[0].isIntersecting) {
                    setTimeout(type, 500);
                    typingObserver.disconnect();
                }
            }, { threshold: 0.5 });

            typingObserver.observe(searchDemo);
        }
    }
});

function toggleLanguage() {
    currentLang = currentLang === 'en' ? 'ko' : 'en';
    applyTranslations(currentLang);
    updateLangIndicator();
    localStorage.setItem('cmdtrace-lang', currentLang);
    document.documentElement.setAttribute('lang', currentLang);
    document.documentElement.setAttribute('data-lang', currentLang);
}

function applyTranslations(lang) {
    const t = translations[lang];

    document.querySelectorAll('[data-i18n]').forEach(el => {
        const key = el.getAttribute('data-i18n');
        if (t[key]) {
            if (t[key].includes('<br>') || t[key].includes('<strong>')) {
                el.innerHTML = t[key];
            } else {
                el.textContent = t[key];
            }
        }
    });
}

function updateLangIndicator() {
    const indicator = document.querySelector('.lang-indicator');
    if (indicator) {
        indicator.textContent = currentLang.toUpperCase();
    }
}
