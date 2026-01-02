# AI Agent Configurations

This directory contains specialized AI agent configurations for the Upload Portal project.

## Available Agents

### 🚀 Deployment Expert

**File**: [deployment-expert.md](deployment-expert.md)

**Specialization**: Fly.io deployments for Elixir/Phoenix applications

**Use When**:
- Planning or executing Fly.io deployments
- Troubleshooting deployment issues
- Configuring infrastructure (databases, volumes, networking)
- Implementing security best practices for production
- Optimizing deployment configurations
- Setting up monitoring and alerting

**Knowledge Sources**:
- Fly.io Elixir documentation
- Phoenix deployment guides
- Ecto production configuration
- Docker best practices for Elixir
- Security hardening guides

**Example Use Cases**:
1. "How do I configure database SSL with peer verification on Fly.io?"
2. "What's the recommended fly.toml configuration for a Phoenix app?"
3. "How should I handle database migrations in production?"
4. "What security headers should I configure for my Phoenix endpoint?"
5. "How do I set up health checks for my application?"
6. "What's the best way to configure persistent storage on Fly.io?"

## How to Use Agents

When working with AI assistants on this project:

1. **Identify the Task Type**: Determine if your question/task matches an agent's specialization

2. **Reference the Agent**: Point your AI assistant to the relevant agent configuration:
   ```
   "Please reference the deployment-expert agent configuration at
   .github/agents/deployment-expert.md for this task."
   ```

3. **Provide Context**: Include relevant project information:
   - Current issue/task you're working on
   - Relevant files or documentation
   - Any errors or logs if troubleshooting

4. **Follow Best Practices**: Agents are configured with best practices and authoritative sources

## Agent Structure

Each agent configuration includes:

- **Purpose**: When and why to use the agent
- **Knowledge Sources**: Authoritative documentation and resources
- **Capabilities**: What the agent can help with
- **Usage Examples**: Common scenarios and use cases
- **Best Practices**: Guidelines for optimal results
- **Project Context**: Specific information about this project

## Adding New Agents

To add a new specialized agent:

1. Create a new markdown file in this directory
2. Follow the structure of existing agents
3. Define clear purpose and scope
4. List authoritative knowledge sources
5. Provide usage examples
6. Update this README

## Integration with Project

These agents integrate with:
- **Deployment Plan**: `docs/FLY_IO_DEPLOYMENT_PLAN.md`
- **Issue Templates**: `.github/ISSUE_TEMPLATE/`
- **Project Documentation**: `docs/`

## Benefits

Using specialized agents provides:
- ✅ **Accurate Information**: Responses based on official documentation
- ✅ **Consistency**: Standardized approaches across the team
- ✅ **Best Practices**: Security and performance best practices baked in
- ✅ **Efficiency**: Faster problem-solving with focused expertise
- ✅ **Knowledge Retention**: Documented approaches for future reference

## Maintenance

Keep agent configurations updated when:
- Documentation links change
- New versions are released (Fly.io, Phoenix, Elixir)
- Best practices evolve
- New features are added
- Project requirements change

---

**Last Updated**: 2026-01-02
**Maintained By**: Development Team
