# SurveyShark 🦈

A production-ready Rails 8 application for conducting AI-powered user interviews and generating actionable insights from conversations.

## ✨ Features

- **🤖 AI-Powered Interviews**: Intelligent conversation flow using OpenAI GPT-4 with streaming responses
- **⚡ Real-time Chat**: Turbo Streams for live conversation updates and seamless user experience
- **🔒 PII Protection**: Automatic detection and masking of personal information for privacy compliance
- **📊 Insight Generation**: Automated analysis and theme extraction using RAKE + LLM pipeline
- **📈 Admin Dashboard**: Comprehensive project management with real-time KPIs and analytics
- **🎨 Responsive Design**: Mobile-friendly interface built with Tailwind CSS and Hotwire
- **🚀 Production Ready**: Complete deployment configuration with Kamal, Docker, and Let's Encrypt
- **🧪 Comprehensive Testing**: 100+ tests covering all functionality with system tests

## 🛠 Tech Stack

- **Backend**: Rails 8.0, SQLite (WAL mode), Solid Queue for background jobs
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS, responsive design
- **AI/ML**: OpenAI GPT-4 with streaming support, RAKE keyword extraction, automated PII detection
- **Deployment**: Kamal with Docker, Traefik reverse proxy, Let's Encrypt SSL
- **Testing**: Minitest with comprehensive unit, integration, and system tests
- **Security**: PII masking, admin authentication, input validation, HTTPS enforcement

## 🚀 Quick Start

### Development Setup

1. **Prerequisites**
   ```bash
   # Ruby 3.4.5 (check .ruby-version)
   ruby --version  # Should be 3.4.5
   
   # Node.js for asset compilation
   node --version  # v18+ recommended
   
   # SQLite 3
   sqlite3 --version  # 3.8+ required
   ```

2. **Clone and Setup**
   ```bash
   git clone <repository-url>
   cd survey-shark
   bundle install
   bin/rails db:setup
   bin/rails db:seed
   ```

3. **Environment Variables**
   ```bash
   # For AI functionality (optional in development)
   export OPENAI_API_KEY=your_openai_api_key_here
   
   # Or create .env file
   echo "OPENAI_API_KEY=your_openai_api_key" > .env
   ```

4. **Start Development Server**
   ```bash
   # Start all services (Rails + CSS/JS compilation)
   bin/dev
   
   # Or start Rails only
   bin/rails server
   ```

5. **Access Application**
   - **Admin Dashboard**: http://localhost:3000 
     - Email: `admin@example.com`
     - Password: `password123`
   - **Health Check**: http://localhost:3000/up
   - **Sample Invite**: Check console output for invite URL after seeding

### 🌐 Production Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for complete production deployment instructions using Kamal with Docker, Traefik, and Let's Encrypt SSL.

**Quick Deploy:**
```bash
# Configure secrets
cp .kamal/secrets.example .kamal/secrets
# Edit .kamal/secrets with your values

# Update config/deploy.yml with your domain and server
# Then deploy
kamal setup
kamal deploy
```

## 📋 Usage

### Admin Workflow

1. **Create Project**: Set up interview parameters, limits, and constraints
2. **Generate Invite Link**: Create public URL for participants
3. **Monitor Progress**: Track responses and KPIs in real-time
4. **Review Insights**: Analyze generated themes and pain points

### Participant Workflow

1. **Access Invite**: Visit public invite link
2. **Provide Consent**: Agree to participate in interview
3. **Enter Attributes**: Provide age and custom attributes
4. **Chat Interview**: Engage in AI-guided conversation
5. **Complete**: Receive thank you message with option to restart

## 🏗 Architecture

### Core Models

- **Project**: Interview configuration and settings
- **InviteLink**: Public access tokens for participants
- **Participant**: Anonymous user data and attributes
- **Conversation**: Interview session with state tracking
- **Message**: Individual chat messages (user/assistant)
- **InsightCard**: Generated themes and analysis results

### Key Services

- **Interview::Orchestrator**: Manages conversation flow and state
- **LLM::Client**: OpenAI integration with streaming support
- **PII::Detector**: Automatic personal information detection
- **Analysis::ConversationAnalyzer**: Theme extraction and insights

### Background Jobs

- **StreamAssistantResponseJob**: Real-time AI response generation
- **PiiDetectJob**: Asynchronous PII detection and masking
- **AnalyzeConversationJob**: Post-conversation analysis and insights

## ⚙️ Configuration

### Environment Variables

- `OPENAI_API_KEY` - Required for AI functionality
- `RAILS_MASTER_KEY` - Rails encryption key (production)
- `RAILS_ENV` - Environment (development/production)

### Project Settings

- **Tone**: Conversation style (polite_soft, casual_friendly, professional)
- **Limits**: Max turns, max deep-dive questions
- **Must Ask**: Required topics to cover
- **Never Ask**: Forbidden topics
- **Max Responses**: Participant limit before auto-close

## 🧪 Testing

```bash
# Run all tests
bin/rails test

# Run specific test types
bin/rails test:models
bin/rails test:controllers
bin/rails test:system

# Run with coverage
COVERAGE=true bin/rails test
```

## 🔒 Security

- **PII Protection**: Automatic detection and masking
- **Admin Authentication**: Secure admin-only access
- **Input Validation**: Comprehensive parameter filtering
- **Rate Limiting**: Built-in conversation flow controls
- **Secure Deployment**: HTTPS with Let's Encrypt

## ⚡ Performance

- **SQLite WAL Mode**: Optimized for concurrent reads
- **Solid Queue**: Efficient background job processing
- **Turbo Streams**: Real-time updates without polling
- **Asset Pipeline**: Optimized CSS/JS delivery
- **Docker**: Containerized deployment

## 📊 Monitoring

- **Health Checks**: `/up` endpoint for monitoring
- **Structured Logging**: JSON logs in production
- **Error Tracking**: Built-in Rails error handling
- **KPI Dashboard**: Real-time project metrics

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass (`bin/rails test`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For deployment issues, see [DEPLOYMENT.md](DEPLOYMENT.md).

For application-specific questions:
1. Check the logs: `bin/rails logs` (development) or `kamal app logs` (production)
2. Verify environment variables are set correctly
3. Test the health check endpoint: `/up`
4. Review the test suite for expected behavior

## 🗺 Roadmap

- [ ] Multi-language support
- [ ] Advanced analytics and reporting
- [ ] Integration with external survey tools
- [ ] Mobile app support
- [ ] Advanced PII detection rules
- [ ] Custom AI model support

---

**Built with ❤️ using Rails 8, Hotwire, and OpenAI**
