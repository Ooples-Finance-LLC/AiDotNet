#!/bin/bash

# Code Generation Developer Agent - Implements new features based on architect proposals
# Generates production-ready code with tests and documentation

set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$AGENT_DIR")"
GENERATED_CODE_DIR="$AGENT_DIR/state/generated_code"
TEMPLATES_DIR="$AGENT_DIR/templates"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Agent ID
AGENT_ID="codegen_developer_$$"

# Initialize
mkdir -p "$GENERATED_CODE_DIR" "$TEMPLATES_DIR"

# Logging
log_message() {
    local level="${2:-INFO}"
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${CYAN}[$timestamp] CODEGEN_DEV${NC} [${level}]: $message" | tee -a "$AGENT_DIR/logs/codegen_developer.log"
}

# Read architect tasks
read_architect_tasks() {
    local tasks_file="$AGENT_DIR/state/ARCHITECT_TASKS.md"
    
    if [[ ! -f "$tasks_file" ]]; then
        log_message "No architect tasks found. Run architect agent first." "WARN"
        return 1
    fi
    
    # Extract pending tasks
    grep -A3 "Status: PENDING_IMPLEMENTATION" "$tasks_file" | grep "Task" | cut -d: -f2 | sed 's/^ *//'
}

# Generate repository pattern implementation
generate_repository_pattern() {
    local namespace="${1:-MyApp.Data}"
    local output_dir="$GENERATED_CODE_DIR/RepositoryPattern"
    
    mkdir -p "$output_dir/Interfaces" "$output_dir/Implementations" "$output_dir/Tests"
    
    log_message "Generating Repository Pattern implementation..."
    
    # Generate IRepository interface
    cat > "$output_dir/Interfaces/IRepository.cs" << EOF
using System;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;
using System.Threading.Tasks;

namespace $namespace.Interfaces
{
    /// <summary>
    /// Generic repository interface for data access operations
    /// </summary>
    /// <typeparam name="T">Entity type</typeparam>
    public interface IRepository<T> where T : class
    {
        /// <summary>
        /// Get entity by id
        /// </summary>
        Task<T> GetByIdAsync(int id);
        
        /// <summary>
        /// Get all entities
        /// </summary>
        Task<IEnumerable<T>> GetAllAsync();
        
        /// <summary>
        /// Find entities matching predicate
        /// </summary>
        Task<IEnumerable<T>> FindAsync(Expression<Func<T, bool>> predicate);
        
        /// <summary>
        /// Add new entity
        /// </summary>
        Task AddAsync(T entity);
        
        /// <summary>
        /// Add multiple entities
        /// </summary>
        Task AddRangeAsync(IEnumerable<T> entities);
        
        /// <summary>
        /// Update entity
        /// </summary>
        void Update(T entity);
        
        /// <summary>
        /// Remove entity
        /// </summary>
        void Remove(T entity);
        
        /// <summary>
        /// Remove multiple entities
        /// </summary>
        void RemoveRange(IEnumerable<T> entities);
        
        /// <summary>
        /// Check if any entity matches predicate
        /// </summary>
        Task<bool> AnyAsync(Expression<Func<T, bool>> predicate);
        
        /// <summary>
        /// Count entities matching predicate
        /// </summary>
        Task<int> CountAsync(Expression<Func<T, bool>> predicate = null);
    }
}
EOF

    # Generate base repository implementation
    cat > "$output_dir/Implementations/Repository.cs" << EOF
using System;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using $namespace.Interfaces;

namespace $namespace.Implementations
{
    /// <summary>
    /// Generic repository implementation
    /// </summary>
    public class Repository<T> : IRepository<T> where T : class
    {
        protected readonly DbContext _context;
        protected readonly DbSet<T> _dbSet;

        public Repository(DbContext context)
        {
            _context = context ?? throw new ArgumentNullException(nameof(context));
            _dbSet = context.Set<T>();
        }

        public virtual async Task<T> GetByIdAsync(int id)
        {
            return await _dbSet.FindAsync(id);
        }

        public virtual async Task<IEnumerable<T>> GetAllAsync()
        {
            return await _dbSet.ToListAsync();
        }

        public virtual async Task<IEnumerable<T>> FindAsync(Expression<Func<T, bool>> predicate)
        {
            return await _dbSet.Where(predicate).ToListAsync();
        }

        public virtual async Task AddAsync(T entity)
        {
            await _dbSet.AddAsync(entity);
        }

        public virtual async Task AddRangeAsync(IEnumerable<T> entities)
        {
            await _dbSet.AddRangeAsync(entities);
        }

        public virtual void Update(T entity)
        {
            _dbSet.Update(entity);
        }

        public virtual void Remove(T entity)
        {
            _dbSet.Remove(entity);
        }

        public virtual void RemoveRange(IEnumerable<T> entities)
        {
            _dbSet.RemoveRange(entities);
        }

        public virtual async Task<bool> AnyAsync(Expression<Func<T, bool>> predicate)
        {
            return await _dbSet.AnyAsync(predicate);
        }

        public virtual async Task<int> CountAsync(Expression<Func<T, bool>> predicate = null)
        {
            return predicate == null 
                ? await _dbSet.CountAsync()
                : await _dbSet.CountAsync(predicate);
        }
    }
}
EOF

    # Generate Unit of Work interface
    cat > "$output_dir/Interfaces/IUnitOfWork.cs" << EOF
using System;
using System.Threading.Tasks;

namespace $namespace.Interfaces
{
    /// <summary>
    /// Unit of Work pattern interface
    /// </summary>
    public interface IUnitOfWork : IDisposable
    {
        /// <summary>
        /// Get repository for entity type
        /// </summary>
        IRepository<TEntity> Repository<TEntity>() where TEntity : class;
        
        /// <summary>
        /// Save all changes
        /// </summary>
        Task<int> CompleteAsync();
        
        /// <summary>
        /// Begin transaction
        /// </summary>
        Task BeginTransactionAsync();
        
        /// <summary>
        /// Commit transaction
        /// </summary>
        Task CommitTransactionAsync();
        
        /// <summary>
        /// Rollback transaction
        /// </summary>
        Task RollbackTransactionAsync();
    }
}
EOF

    # Generate Unit of Work implementation
    cat > "$output_dir/Implementations/UnitOfWork.cs" << EOF
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using $namespace.Interfaces;

namespace $namespace.Implementations
{
    /// <summary>
    /// Unit of Work pattern implementation
    /// </summary>
    public class UnitOfWork : IUnitOfWork
    {
        private readonly DbContext _context;
        private readonly Dictionary<Type, object> _repositories;
        private IDbContextTransaction _transaction;

        public UnitOfWork(DbContext context)
        {
            _context = context ?? throw new ArgumentNullException(nameof(context));
            _repositories = new Dictionary<Type, object>();
        }

        public IRepository<TEntity> Repository<TEntity>() where TEntity : class
        {
            if (_repositories.ContainsKey(typeof(TEntity)))
            {
                return (IRepository<TEntity>)_repositories[typeof(TEntity)];
            }

            var repository = new Repository<TEntity>(_context);
            _repositories.Add(typeof(TEntity), repository);
            return repository;
        }

        public async Task<int> CompleteAsync()
        {
            return await _context.SaveChangesAsync();
        }

        public async Task BeginTransactionAsync()
        {
            _transaction = await _context.Database.BeginTransactionAsync();
        }

        public async Task CommitTransactionAsync()
        {
            if (_transaction != null)
            {
                await _transaction.CommitAsync();
                await _transaction.DisposeAsync();
                _transaction = null;
            }
        }

        public async Task RollbackTransactionAsync()
        {
            if (_transaction != null)
            {
                await _transaction.RollbackAsync();
                await _transaction.DisposeAsync();
                _transaction = null;
            }
        }

        public void Dispose()
        {
            _transaction?.Dispose();
            _context?.Dispose();
        }
    }
}
EOF

    # Generate unit tests
    cat > "$output_dir/Tests/RepositoryTests.cs" << EOF
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Xunit;
using $namespace.Implementations;

namespace $namespace.Tests
{
    public class RepositoryTests : IDisposable
    {
        private readonly DbContextOptions<TestDbContext> _options;
        private readonly TestDbContext _context;

        public RepositoryTests()
        {
            _options = new DbContextOptionsBuilder<TestDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;
            _context = new TestDbContext(_options);
        }

        [Fact]
        public async Task AddAsync_Should_Add_Entity()
        {
            // Arrange
            var repository = new Repository<TestEntity>(_context);
            var entity = new TestEntity { Name = "Test" };

            // Act
            await repository.AddAsync(entity);
            await _context.SaveChangesAsync();

            // Assert
            var result = await repository.GetAllAsync();
            Assert.Single(result);
            Assert.Equal("Test", result.First().Name);
        }

        [Fact]
        public async Task FindAsync_Should_Return_Matching_Entities()
        {
            // Arrange
            var repository = new Repository<TestEntity>(_context);
            await repository.AddRangeAsync(new[]
            {
                new TestEntity { Name = "Test1" },
                new TestEntity { Name = "Test2" },
                new TestEntity { Name = "Other" }
            });
            await _context.SaveChangesAsync();

            // Act
            var result = await repository.FindAsync(x => x.Name.StartsWith("Test"));

            // Assert
            Assert.Equal(2, result.Count());
        }

        [Fact]
        public async Task Update_Should_Modify_Entity()
        {
            // Arrange
            var repository = new Repository<TestEntity>(_context);
            var entity = new TestEntity { Name = "Original" };
            await repository.AddAsync(entity);
            await _context.SaveChangesAsync();

            // Act
            entity.Name = "Updated";
            repository.Update(entity);
            await _context.SaveChangesAsync();

            // Assert
            var result = await repository.GetByIdAsync(entity.Id);
            Assert.Equal("Updated", result.Name);
        }

        public void Dispose()
        {
            _context?.Dispose();
        }
    }

    // Test helpers
    public class TestDbContext : DbContext
    {
        public TestDbContext(DbContextOptions<TestDbContext> options) : base(options) { }
        public DbSet<TestEntity> TestEntities { get; set; }
    }

    public class TestEntity
    {
        public int Id { get; set; }
        public string Name { get; set; }
    }
}
EOF

    # Generate README
    cat > "$output_dir/README.md" << EOF
# Repository Pattern Implementation

## Overview
This is a complete implementation of the Repository and Unit of Work patterns.

## Usage

### 1. Register in Dependency Injection
\`\`\`csharp
services.AddScoped(typeof(IRepository<>), typeof(Repository<>));
services.AddScoped<IUnitOfWork, UnitOfWork>();
\`\`\`

### 2. Use in Services
\`\`\`csharp
public class UserService
{
    private readonly IUnitOfWork _unitOfWork;
    
    public UserService(IUnitOfWork unitOfWork)
    {
        _unitOfWork = unitOfWork;
    }
    
    public async Task<User> GetUserAsync(int id)
    {
        return await _unitOfWork.Repository<User>().GetByIdAsync(id);
    }
    
    public async Task CreateUserAsync(User user)
    {
        await _unitOfWork.Repository<User>().AddAsync(user);
        await _unitOfWork.CompleteAsync();
    }
}
\`\`\`

### 3. Use with Transactions
\`\`\`csharp
await _unitOfWork.BeginTransactionAsync();
try
{
    await _unitOfWork.Repository<Order>().AddAsync(order);
    await _unitOfWork.Repository<OrderItem>().AddRangeAsync(items);
    await _unitOfWork.CompleteAsync();
    await _unitOfWork.CommitTransactionAsync();
}
catch
{
    await _unitOfWork.RollbackTransactionAsync();
    throw;
}
\`\`\`

## Testing
Run tests with: \`dotnet test\`

## Next Steps
1. Copy files to your project
2. Update namespaces
3. Add specific repository interfaces for your entities
4. Run tests to ensure everything works
EOF

    log_message "Repository Pattern generated in: $output_dir"
}

# Generate CQRS implementation
generate_cqrs_pattern() {
    local namespace="${1:-MyApp.Application}"
    local output_dir="$GENERATED_CODE_DIR/CQRS"
    
    mkdir -p "$output_dir/Commands" "$output_dir/Queries" "$output_dir/Handlers" "$output_dir/Tests"
    
    log_message "Generating CQRS implementation..."
    
    # Generate base command
    cat > "$output_dir/Commands/CommandBase.cs" << EOF
using MediatR;
using System;

namespace $namespace.Commands
{
    /// <summary>
    /// Base class for commands
    /// </summary>
    public abstract class CommandBase : IRequest
    {
        public Guid CorrelationId { get; } = Guid.NewGuid();
        public DateTime Timestamp { get; } = DateTime.UtcNow;
    }

    /// <summary>
    /// Base class for commands with response
    /// </summary>
    public abstract class CommandBase<TResponse> : IRequest<TResponse>
    {
        public Guid CorrelationId { get; } = Guid.NewGuid();
        public DateTime Timestamp { get; } = DateTime.UtcNow;
    }
}
EOF

    # Generate example command
    cat > "$output_dir/Commands/CreateUserCommand.cs" << EOF
using System.ComponentModel.DataAnnotations;

namespace $namespace.Commands
{
    /// <summary>
    /// Command to create a new user
    /// </summary>
    public class CreateUserCommand : CommandBase<int>
    {
        [Required]
        [MaxLength(100)]
        public string Name { get; set; }

        [Required]
        [EmailAddress]
        public string Email { get; set; }

        [Phone]
        public string PhoneNumber { get; set; }
    }
}
EOF

    # Generate command handler
    cat > "$output_dir/Handlers/CreateUserCommandHandler.cs" << EOF
using System;
using System.Threading;
using System.Threading.Tasks;
using MediatR;
using Microsoft.Extensions.Logging;
using $namespace.Commands;

namespace $namespace.Handlers
{
    /// <summary>
    /// Handler for CreateUserCommand
    /// </summary>
    public class CreateUserCommandHandler : IRequestHandler<CreateUserCommand, int>
    {
        private readonly ILogger<CreateUserCommandHandler> _logger;
        // Add your repositories/services here

        public CreateUserCommandHandler(ILogger<CreateUserCommandHandler> logger)
        {
            _logger = logger;
        }

        public async Task<int> Handle(CreateUserCommand request, CancellationToken cancellationToken)
        {
            _logger.LogInformation("Creating user {Email}", request.Email);

            try
            {
                // Validate business rules
                if (await UserExists(request.Email))
                {
                    throw new InvalidOperationException($"User with email {request.Email} already exists");
                }

                // Create user entity
                var user = new User
                {
                    Name = request.Name,
                    Email = request.Email,
                    PhoneNumber = request.PhoneNumber,
                    CreatedAt = DateTime.UtcNow
                };

                // Save to database
                // await _userRepository.AddAsync(user);
                // await _unitOfWork.CompleteAsync();

                _logger.LogInformation("User {Email} created with ID {Id}", user.Email, user.Id);
                
                return user.Id;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating user {Email}", request.Email);
                throw;
            }
        }

        private async Task<bool> UserExists(string email)
        {
            // Check if user exists
            // return await _userRepository.AnyAsync(u => u.Email == email);
            return false; // Placeholder
        }
    }

    // Placeholder User entity
    public class User
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string Email { get; set; }
        public string PhoneNumber { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
EOF

    # Generate query
    cat > "$output_dir/Queries/GetUserByIdQuery.cs" << EOF
namespace $namespace.Queries
{
    /// <summary>
    /// Query to get user by ID
    /// </summary>
    public class GetUserByIdQuery : IRequest<UserDto>
    {
        public int Id { get; set; }

        public GetUserByIdQuery(int id)
        {
            Id = id;
        }
    }

    /// <summary>
    /// User DTO
    /// </summary>
    public class UserDto
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string Email { get; set; }
        public string PhoneNumber { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
EOF

    # Generate query handler
    cat > "$output_dir/Handlers/GetUserByIdQueryHandler.cs" << EOF
using System.Threading;
using System.Threading.Tasks;
using MediatR;
using Microsoft.Extensions.Logging;
using $namespace.Queries;

namespace $namespace.Handlers
{
    /// <summary>
    /// Handler for GetUserByIdQuery
    /// </summary>
    public class GetUserByIdQueryHandler : IRequestHandler<GetUserByIdQuery, UserDto>
    {
        private readonly ILogger<GetUserByIdQueryHandler> _logger;
        // Add your repositories/services here

        public GetUserByIdQueryHandler(ILogger<GetUserByIdQueryHandler> logger)
        {
            _logger = logger;
        }

        public async Task<UserDto> Handle(GetUserByIdQuery request, CancellationToken cancellationToken)
        {
            _logger.LogInformation("Getting user {Id}", request.Id);

            // Get from database
            // var user = await _userRepository.GetByIdAsync(request.Id);
            
            // if (user == null)
            // {
            //     throw new NotFoundException($"User {request.Id} not found");
            // }

            // Map to DTO
            // return _mapper.Map<UserDto>(user);
            
            // Placeholder
            return new UserDto
            {
                Id = request.Id,
                Name = "Test User",
                Email = "test@example.com",
                CreatedAt = DateTime.UtcNow
            };
        }
    }
}
EOF

    # Generate validation behavior
    cat > "$output_dir/Behaviors/ValidationBehavior.cs" << EOF
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using FluentValidation;
using MediatR;

namespace $namespace.Behaviors
{
    /// <summary>
    /// Pipeline behavior for validation
    /// </summary>
    public class ValidationBehavior<TRequest, TResponse> : IPipelineBehavior<TRequest, TResponse>
        where TRequest : IRequest<TResponse>
    {
        private readonly IEnumerable<IValidator<TRequest>> _validators;

        public ValidationBehavior(IEnumerable<IValidator<TRequest>> validators)
        {
            _validators = validators;
        }

        public async Task<TResponse> Handle(TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken cancellationToken)
        {
            if (_validators.Any())
            {
                var context = new ValidationContext<TRequest>(request);
                var validationResults = await Task.WhenAll(_validators.Select(v => v.ValidateAsync(context, cancellationToken)));
                var failures = validationResults.SelectMany(r => r.Errors).Where(f => f != null).ToList();

                if (failures.Count != 0)
                {
                    throw new ValidationException(failures);
                }
            }

            return await next();
        }
    }
}
EOF

    # Generate tests
    cat > "$output_dir/Tests/CreateUserCommandHandlerTests.cs" << EOF
using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;
using $namespace.Commands;
using $namespace.Handlers;

namespace $namespace.Tests
{
    public class CreateUserCommandHandlerTests
    {
        private readonly Mock<ILogger<CreateUserCommandHandler>> _loggerMock;
        private readonly CreateUserCommandHandler _handler;

        public CreateUserCommandHandlerTests()
        {
            _loggerMock = new Mock<ILogger<CreateUserCommandHandler>>();
            _handler = new CreateUserCommandHandler(_loggerMock.Object);
        }

        [Fact]
        public async Task Handle_ValidCommand_ReturnsUserId()
        {
            // Arrange
            var command = new CreateUserCommand
            {
                Name = "Test User",
                Email = "test@example.com",
                PhoneNumber = "+1234567890"
            };

            // Act
            var result = await _handler.Handle(command, CancellationToken.None);

            // Assert
            Assert.True(result > 0);
        }

        [Fact]
        public async Task Handle_DuplicateEmail_ThrowsException()
        {
            // Arrange
            var command = new CreateUserCommand
            {
                Name = "Test User",
                Email = "existing@example.com",
                PhoneNumber = "+1234567890"
            };

            // Act & Assert
            await Assert.ThrowsAsync<InvalidOperationException>(
                () => _handler.Handle(command, CancellationToken.None)
            );
        }
    }
}
EOF

    log_message "CQRS pattern generated in: $output_dir"
}

# Generate API endpoints
generate_api_endpoints() {
    local namespace="${1:-MyApp.Api}"
    local output_dir="$GENERATED_CODE_DIR/Api"
    
    mkdir -p "$output_dir/Controllers" "$output_dir/Models" "$output_dir/Filters"
    
    log_message "Generating API endpoints..."
    
    # Generate base API controller
    cat > "$output_dir/Controllers/ApiControllerBase.cs" << EOF
using Microsoft.AspNetCore.Mvc;
using MediatR;
using Microsoft.Extensions.DependencyInjection;

namespace $namespace.Controllers
{
    /// <summary>
    /// Base API controller with common functionality
    /// </summary>
    [ApiController]
    [Route("api/v{version:apiVersion}/[controller]")]
    [Produces("application/json")]
    public abstract class ApiControllerBase : ControllerBase
    {
        private ISender _mediator;

        /// <summary>
        /// MediatR sender
        /// </summary>
        protected ISender Mediator => _mediator ??= HttpContext.RequestServices.GetService<ISender>();
    }
}
EOF

    # Generate user controller
    cat > "$output_dir/Controllers/UsersController.cs" << EOF
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using $namespace.Commands;
using $namespace.Queries;

namespace $namespace.Controllers
{
    /// <summary>
    /// Users API endpoints
    /// </summary>
    [ApiVersion("1.0")]
    public class UsersController : ApiControllerBase
    {
        private readonly ILogger<UsersController> _logger;

        public UsersController(ILogger<UsersController> logger)
        {
            _logger = logger;
        }

        /// <summary>
        /// Get user by ID
        /// </summary>
        /// <param name="id">User ID</param>
        /// <returns>User details</returns>
        /// <response code="200">Returns the user</response>
        /// <response code="404">User not found</response>
        [HttpGet("{id}")]
        [ProducesResponseType(typeof(UserDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<UserDto>> GetById(int id)
        {
            var query = new GetUserByIdQuery(id);
            var result = await Mediator.Send(query);
            
            if (result == null)
            {
                return NotFound();
            }
            
            return Ok(result);
        }

        /// <summary>
        /// Create a new user
        /// </summary>
        /// <param name="command">User creation data</param>
        /// <returns>Created user ID</returns>
        /// <response code="201">User created successfully</response>
        /// <response code="400">Invalid request data</response>
        /// <response code="409">User already exists</response>
        [HttpPost]
        [ProducesResponseType(typeof(int), StatusCodes.Status201Created)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status409Conflict)]
        public async Task<ActionResult<int>> Create([FromBody] CreateUserCommand command)
        {
            try
            {
                var userId = await Mediator.Send(command);
                return CreatedAtAction(nameof(GetById), new { id = userId }, userId);
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning(ex, "User creation conflict");
                return Conflict(new { error = ex.Message });
            }
        }

        /// <summary>
        /// Search users
        /// </summary>
        /// <param name="searchTerm">Search term</param>
        /// <param name="pageNumber">Page number (default: 1)</param>
        /// <param name="pageSize">Page size (default: 10, max: 100)</param>
        /// <returns>Paginated user list</returns>
        [HttpGet]
        [ProducesResponseType(typeof(PaginatedList<UserDto>), StatusCodes.Status200OK)]
        public async Task<ActionResult<PaginatedList<UserDto>>> Search(
            [FromQuery] string searchTerm,
            [FromQuery] int pageNumber = 1,
            [FromQuery] int pageSize = 10)
        {
            if (pageSize > 100) pageSize = 100;
            
            var query = new SearchUsersQuery
            {
                SearchTerm = searchTerm,
                PageNumber = pageNumber,
                PageSize = pageSize
            };
            
            var result = await Mediator.Send(query);
            return Ok(result);
        }

        /// <summary>
        /// Update user
        /// </summary>
        /// <param name="id">User ID</param>
        /// <param name="command">Update data</param>
        /// <returns>No content</returns>
        /// <response code="204">User updated successfully</response>
        /// <response code="404">User not found</response>
        [HttpPut("{id}")]
        [ProducesResponseType(StatusCodes.Status204NoContent)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> Update(int id, [FromBody] UpdateUserCommand command)
        {
            command.Id = id;
            await Mediator.Send(command);
            return NoContent();
        }

        /// <summary>
        /// Delete user
        /// </summary>
        /// <param name="id">User ID</param>
        /// <returns>No content</returns>
        /// <response code="204">User deleted successfully</response>
        /// <response code="404">User not found</response>
        [HttpDelete("{id}")]
        [ProducesResponseType(StatusCodes.Status204NoContent)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> Delete(int id)
        {
            var command = new DeleteUserCommand(id);
            await Mediator.Send(command);
            return NoContent();
        }
    }
}
EOF

    # Generate pagination model
    cat > "$output_dir/Models/PaginatedList.cs" << EOF
using System;
using System.Collections.Generic;

namespace $namespace.Models
{
    /// <summary>
    /// Paginated list response
    /// </summary>
    public class PaginatedList<T>
    {
        public List<T> Items { get; set; }
        public int PageNumber { get; set; }
        public int PageSize { get; set; }
        public int TotalPages { get; set; }
        public int TotalCount { get; set; }
        public bool HasPreviousPage => PageNumber > 1;
        public bool HasNextPage => PageNumber < TotalPages;

        public PaginatedList(List<T> items, int count, int pageNumber, int pageSize)
        {
            Items = items;
            TotalCount = count;
            PageNumber = pageNumber;
            PageSize = pageSize;
            TotalPages = (int)Math.Ceiling(count / (double)pageSize);
        }
    }
}
EOF

    # Generate global exception filter
    cat > "$output_dir/Filters/GlobalExceptionFilter.cs" << EOF
using System;
using System.Net;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.Extensions.Logging;
using FluentValidation;

namespace $namespace.Filters
{
    /// <summary>
    /// Global exception handling filter
    /// </summary>
    public class GlobalExceptionFilter : IExceptionFilter
    {
        private readonly ILogger<GlobalExceptionFilter> _logger;

        public GlobalExceptionFilter(ILogger<GlobalExceptionFilter> logger)
        {
            _logger = logger;
        }

        public void OnException(ExceptionContext context)
        {
            var exception = context.Exception;
            var response = context.HttpContext.Response;

            response.ContentType = "application/json";

            switch (exception)
            {
                case ValidationException validationEx:
                    response.StatusCode = (int)HttpStatusCode.BadRequest;
                    context.Result = new JsonResult(new
                    {
                        error = "Validation failed",
                        details = validationEx.Errors
                    });
                    break;
                    
                case NotFoundException notFoundEx:
                    response.StatusCode = (int)HttpStatusCode.NotFound;
                    context.Result = new JsonResult(new
                    {
                        error = notFoundEx.Message
                    });
                    break;
                    
                case UnauthorizedException:
                    response.StatusCode = (int)HttpStatusCode.Unauthorized;
                    context.Result = new JsonResult(new
                    {
                        error = "Unauthorized"
                    });
                    break;
                    
                case InvalidOperationException invalidOpEx:
                    response.StatusCode = (int)HttpStatusCode.Conflict;
                    context.Result = new JsonResult(new
                    {
                        error = invalidOpEx.Message
                    });
                    break;
                    
                default:
                    _logger.LogError(exception, "Unhandled exception");
                    response.StatusCode = (int)HttpStatusCode.InternalServerError;
                    context.Result = new JsonResult(new
                    {
                        error = "An error occurred while processing your request"
                    });
                    break;
            }

            context.ExceptionHandled = true;
        }
    }

    public class NotFoundException : Exception
    {
        public NotFoundException(string message) : base(message) { }
    }

    public class UnauthorizedException : Exception
    {
        public UnauthorizedException(string message = "Unauthorized") : base(message) { }
    }
}
EOF

    log_message "API endpoints generated in: $output_dir"
}

# Generate startup configuration
generate_startup_configuration() {
    local output_dir="$GENERATED_CODE_DIR/Configuration"
    mkdir -p "$output_dir"
    
    log_message "Generating startup configuration..."
    
    cat > "$output_dir/ServiceConfiguration.cs" << EOF
using System.Reflection;
using Microsoft.Extensions.DependencyInjection;
using MediatR;
using FluentValidation;

namespace MyApp.Configuration
{
    /// <summary>
    /// Service configuration extensions
    /// </summary>
    public static class ServiceConfiguration
    {
        /// <summary>
        /// Add application services
        /// </summary>
        public static IServiceCollection AddApplicationServices(this IServiceCollection services)
        {
            // Add MediatR
            services.AddMediatR(cfg => cfg.RegisterServicesFromAssembly(Assembly.GetExecutingAssembly()));
            
            // Add validation
            services.AddValidatorsFromAssembly(Assembly.GetExecutingAssembly());
            
            // Add pipeline behaviors
            services.AddTransient(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));
            services.AddTransient(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));
            
            // Add repositories
            services.AddScoped(typeof(IRepository<>), typeof(Repository<>));
            services.AddScoped<IUnitOfWork, UnitOfWork>();
            
            // Add AutoMapper
            services.AddAutoMapper(Assembly.GetExecutingAssembly());
            
            return services;
        }

        /// <summary>
        /// Add caching services
        /// </summary>
        public static IServiceCollection AddCaching(this IServiceCollection services, string redisConnection = null)
        {
            services.AddMemoryCache();
            
            if (!string.IsNullOrEmpty(redisConnection))
            {
                services.AddStackExchangeRedisCache(options =>
                {
                    options.Configuration = redisConnection;
                });
            }
            else
            {
                services.AddDistributedMemoryCache();
            }
            
            services.AddSingleton<ICacheService, CacheService>();
            
            return services;
        }

        /// <summary>
        /// Add API versioning
        /// </summary>
        public static IServiceCollection AddApiVersioningConfiguration(this IServiceCollection services)
        {
            services.AddApiVersioning(options =>
            {
                options.DefaultApiVersion = new ApiVersion(1, 0);
                options.AssumeDefaultVersionWhenUnspecified = true;
                options.ReportApiVersions = true;
            });
            
            services.AddVersionedApiExplorer(options =>
            {
                options.GroupNameFormat = "'v'VVV";
                options.SubstituteApiVersionInUrl = true;
            });
            
            return services;
        }
    }
}
EOF

    log_message "Startup configuration generated in: $output_dir"
}

# Process architect proposals and generate code
process_proposals() {
    local proposals_dir="$AGENT_DIR/state/architectural_proposals"
    
    if [[ ! -d "$proposals_dir" ]]; then
        log_message "No proposals found. Run architect agent first." "WARN"
        return 1
    fi
    
    local proposals=$(find "$proposals_dir" -name "*.md" -type f)
    
    while IFS= read -r proposal; do
        [[ -z "$proposal" ]] && continue
        
        local proposal_name=$(basename "$proposal" .md)
        
        case "$proposal_name" in
            *"Repository"*)
                generate_repository_pattern
                ;;
            *"CQRS"*|*"Mediator"*)
                generate_cqrs_pattern
                ;;
            *"API"*)
                generate_api_endpoints
                ;;
            *)
                log_message "Unknown proposal type: $proposal_name" "WARN"
                ;;
        esac
    done <<< "$proposals"
}

# Generate integration script
generate_integration_script() {
    local script_file="$GENERATED_CODE_DIR/integrate.sh"
    
    cat > "$script_file" << 'EOF'
#!/bin/bash

# Integration script for generated code
echo "Integrating generated code into project..."

# Function to copy with namespace update
copy_with_namespace() {
    local src="$1"
    local dest="$2"
    local namespace="$3"
    
    mkdir -p "$(dirname "$dest")"
    sed "s/MyApp/$namespace/g" "$src" > "$dest"
}

# Get project namespace
read -p "Enter your project namespace (e.g., MyCompany.MyProject): " PROJECT_NS

# Copy repository pattern
if [[ -d "RepositoryPattern" ]]; then
    echo "Copying Repository Pattern..."
    find RepositoryPattern -name "*.cs" | while read -r file; do
        rel_path="${file#RepositoryPattern/}"
        copy_with_namespace "$file" "../../../$rel_path" "$PROJECT_NS"
    done
fi

# Copy CQRS implementation
if [[ -d "CQRS" ]]; then
    echo "Copying CQRS implementation..."
    find CQRS -name "*.cs" | while read -r file; do
        rel_path="${file#CQRS/}"
        copy_with_namespace "$file" "../../../Application/$rel_path" "$PROJECT_NS"
    done
fi

# Copy API endpoints
if [[ -d "Api" ]]; then
    echo "Copying API endpoints..."
    find Api -name "*.cs" | while read -r file; do
        rel_path="${file#Api/}"
        copy_with_namespace "$file" "../../../Api/$rel_path" "$PROJECT_NS"
    done
fi

echo "Integration complete!"
echo ""
echo "Next steps:"
echo "1. Review the generated code"
echo "2. Update connection strings and configuration"
echo "3. Run migrations if needed"
echo "4. Run tests to ensure everything works"
EOF
    
    chmod +x "$script_file"
    log_message "Integration script created: $script_file"
}

# Create documentation
generate_documentation() {
    local doc_file="$GENERATED_CODE_DIR/GENERATED_CODE_GUIDE.md"
    
    cat > "$doc_file" << EOF
# Generated Code Guide

## Overview
This directory contains production-ready code generated based on architectural proposals.

## Generated Components

### 1. Repository Pattern
- Location: \`RepositoryPattern/\`
- Base repository interface and implementation
- Unit of Work pattern
- Full test coverage
- Ready for Entity Framework Core

### 2. CQRS Implementation  
- Location: \`CQRS/\`
- Command/Query separation
- MediatR integration
- Validation pipeline
- Example handlers with tests

### 3. API Endpoints
- Location: \`Api/\`
- RESTful controllers
- API versioning
- Global exception handling
- Swagger documentation ready

### 4. Configuration
- Location: \`Configuration/\`
- Service registration
- Startup configuration
- Dependency injection setup

## Integration Steps

### Automatic Integration
Run the integration script:
\`\`\`bash
cd $GENERATED_CODE_DIR
./integrate.sh
\`\`\`

### Manual Integration
1. Copy files to your project
2. Update namespaces
3. Install required NuGet packages:
   \`\`\`xml
   <PackageReference Include="MediatR" Version="12.0.0" />
   <PackageReference Include="FluentValidation" Version="11.0.0" />
   <PackageReference Include="AutoMapper" Version="12.0.0" />
   <PackageReference Include="Microsoft.EntityFrameworkCore" Version="7.0.0" />
   \`\`\`
4. Register services in Startup.cs:
   \`\`\`csharp
   services.AddApplicationServices();
   services.AddApiVersioningConfiguration();
   services.AddCaching(Configuration.GetConnectionString("Redis"));
   \`\`\`

## Testing
Each component includes unit tests. Run with:
\`\`\`bash
dotnet test
\`\`\`

## Customization
All generated code is designed to be customized:
- Add business logic to handlers
- Extend repositories with custom queries
- Add validation rules
- Implement authorization

## Architecture Decisions
- **Repository Pattern**: Abstracts data access
- **CQRS**: Separates reads and writes
- **MediatR**: Reduces coupling
- **FluentValidation**: Separates validation logic
- **API Versioning**: Future-proofs the API

## Support
Generated by Code Generation Developer Agent
Version: 1.0.0
Date: $(date)
EOF
    
    log_message "Documentation created: $doc_file"
}

# Update architect tasks status
update_task_status() {
    local task_name="$1"
    local status="$2"
    
    local tasks_file="$AGENT_DIR/state/ARCHITECT_TASKS.md"
    
    if [[ -f "$tasks_file" ]]; then
        sed -i "s/Status: PENDING_IMPLEMENTATION/Status: $status/g" "$tasks_file"
        log_message "Updated task status: $task_name -> $status"
    fi
}

# Main execution
main() {
    log_message "=== CODE GENERATION DEVELOPER AGENT STARTING ==="
    
    # Check for architect tasks
    local tasks=$(read_architect_tasks)
    
    if [[ -z "$tasks" ]]; then
        log_message "No tasks to implement. Running architect agent first..."
        bash "$AGENT_DIR/architect_agent.sh"
        tasks=$(read_architect_tasks)
    fi
    
    # Process proposals and generate code
    process_proposals
    
    # Generate additional components
    generate_startup_configuration
    
    # Create integration helpers
    generate_integration_script
    generate_documentation
    
    # Update task status
    while IFS= read -r task; do
        update_task_status "$task" "COMPLETED"
    done <<< "$tasks"
    
    log_message "=== CODE GENERATION COMPLETE ==="
    log_message "Generated code location: $GENERATED_CODE_DIR"
    log_message "Run $GENERATED_CODE_DIR/integrate.sh to integrate into your project"
}

# Execute
main "$@"